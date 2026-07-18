import 'package:card_game/presentation/pages/match_page.dart';
import 'package:card_game/presentation/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_match_repository.dart';

Map<String, dynamic> _cardJson({
  String id = 'card-1',
  String name = 'Bochica, the Civilizer',
  bool inPlay = false,
  bool summoningSick = false,
  bool hasAttackedThisTurn = false,
}) {
  return {
    'player_card_id': id,
    'name': name,
    'faction': 'muisca',
    'rank': 'hero',
    'rarity': 'common',
    'attack': 30,
    'max_defense': 30,
    if (inPlay) 'current_defense': 30,
    if (inPlay) 'summoning_sick': summoningSick,
    if (inPlay) 'has_attacked_this_turn': hasAttackedThisTurn,
  };
}

Map<String, dynamic> _stateJson({
  required bool yourTurn,
  List<Map<String, dynamic>>? yourHand,
  List<Map<String, dynamic>>? yourBoard,
}) {
  return {
    'your_turn': yourTurn,
    'your_life': 20,
    'opponent_life': 20,
    'your_hand': yourHand ?? [],
    'your_board': yourBoard ?? [],
    'opponent_board': [],
    'opponent_hand_count': 3,
    'your_deck_count': 7,
    'opponent_deck_count': 7,
  };
}

Future<FakeMatchRepository> _pumpMatchPageWithState(
  WidgetTester tester,
  Map<String, dynamic> stateJson,
) async {
  // El tablero completo (info rival + su fila de cartas + cartel de turno
  // + tu fila de cartas + tu mano + tu info) no entra en la superficie de
  // test por defecto (800x600) -- mismo ajuste que ya hizo falta en
  // admin_coins_page_test.dart.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = FakeMatchRepository();
  final container = ProviderContainer(
    overrides: [matchRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  await container.read(matchNotifierProvider.notifier).startQueue([]);
  repository.emit({'type': 'state_update', 'state': stateJson});

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MaterialApp(home: MatchPage())),
  );
  // Dos pumps acotados, no pumpAndSettle: (1) deja que el microtask del
  // stream (repository.emit) se procese y el notifier actualice el
  // estado -- en el entorno de test, Future.delayed no avanza solo, así
  // que un pump() explícito es lo que realmente lo destraba; (2) el
  // cartel "tu turno" pulsa indefinidamente
  // (.animate().repeat(reverse: true)), así que pumpAndSettle() nunca
  // settlearía con eso en pantalla -- mismo problema ya documentado para
  // el shimmer de marketplace_page_test.dart.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  return repository;
}

void main() {
  testWidgets('en tu turno, el cartel muestra la acción y termina el turno al tocarlo',
      (tester) async {
    final repository = await _pumpMatchPageWithState(tester, _stateJson(yourTurn: true));

    expect(find.text('TU TURNO — TOCÁ PARA TERMINAR'), findsOneWidget);
    expect(find.text('Terminar turno'), findsNothing); // ya no existe el botón viejo

    await tester.tap(find.text('TU TURNO — TOCÁ PARA TERMINAR'));
    await tester.pump();

    expect(repository.calls, contains('endTurn()'));
  });

  testWidgets('fuera de tu turno, el cartel es solo texto informativo', (tester) async {
    await _pumpMatchPageWithState(tester, _stateJson(yourTurn: false));

    expect(find.text('TURNO DEL RIVAL'), findsOneWidget);
    expect(find.text('TU TURNO — TOCÁ PARA TERMINAR'), findsNothing);
  });

  testWidgets('mantener presionada una carta de la mano abre el detalle', (tester) async {
    await _pumpMatchPageWithState(
      tester,
      _stateJson(yourTurn: true, yourHand: [_cardJson(name: 'Bachué, the Original Mother')]),
    );

    expect(find.text('Bachué, the Original Mother'), findsOneWidget);

    await tester.longPress(find.text('Bachué, the Original Mother'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // El detalle reusa GameCardWidget más grande adentro de un diálogo --
    // dos apariciones del nombre: la carta chica de la mano + la del diálogo.
    expect(find.text('Bachué, the Original Mother'), findsNWidgets(2));
    expect(find.text('CERRAR'), findsOneWidget);
  });

  testWidgets('mantener presionada una carta del tablero también abre el detalle',
      (tester) async {
    await _pumpMatchPageWithState(
      tester,
      _stateJson(
        yourTurn: true,
        yourBoard: [_cardJson(name: 'Chibchacum, the Punished', inPlay: true)],
      ),
    );

    await tester.longPress(find.text('Chibchacum, the Punished'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Chibchacum, the Punished'), findsNWidgets(2));
  });
}
