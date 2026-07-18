import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/domain/entities/coin_grant.dart';
import 'package:card_game/presentation/pages/admin_coins_page.dart';
import 'package:card_game/presentation/providers/admin_coins_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_admin_coins_repository.dart';

Widget _appWith(FakeAdminCoinsRepository repository) {
  return ProviderScope(
    overrides: [adminCoinsRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: AdminCoinsPage()),
  );
}

/// La pantalla tiene dos cards (otorgar/evento) + historial en un solo
/// ListView — con el tamaño default de test (800x600) el botón de evento y
/// el historial quedan fuera del viewport, lo que rompe tanto tap() (no
/// hit-testea) como ListView.separated del historial (no llega a construir
/// sus items fuera del cacheExtent).
Future<void> _growSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('otorgar a un usuario llama al repositorio y muestra el saldo',
      (tester) async {
    await _growSurface(tester);
    final repo = FakeAdminCoinsRepository()..nextBalance = 750;
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Email o username del jugador'), 'squall');
    await tester.enterText(find.widgetWithText(TextField, 'Monto (coins)'), '250');
    await tester.tap(find.text('OTORGAR'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('grant(squall, 250)'));
    expect(find.text('Otorgado. Nuevo saldo: 750 coins.'), findsOneWidget);
  });

  testWidgets('error del servidor al otorgar muestra el mensaje', (tester) async {
    await _growSurface(tester);
    final repo = FakeAdminCoinsRepository()
      ..grantError = ApiException(statusCode: 404, message: "no existe ningún usuario");
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Email o username del jugador'), 'no-existe');
    await tester.enterText(find.widgetWithText(TextField, 'Monto (coins)'), '10');
    await tester.tap(find.text('OTORGAR'));
    await tester.pumpAndSettle();

    expect(find.text('no existe ningún usuario'), findsOneWidget);
  });

  testWidgets('evento a la comunidad pide confirmación antes de llamar al repositorio',
      (tester) async {
    await _growSurface(tester);
    final repo = FakeAdminCoinsRepository()..nextRecipientCount = 42;
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Monto (coins) por usuario'), '100');
    await tester.tap(find.text('LANZAR EVENTO A TODA LA COMUNIDAD'));
    await tester.pumpAndSettle();

    // Todavía no llamó a broadcast() -- espera confirmación del diálogo.
    // (repo.calls ya tiene getHistory() del initState, eso sí es esperado).
    expect(repo.calls, isNot(contains('broadcast(100)')));
    expect(find.text('Confirmar evento'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('broadcast(100)'));
    expect(find.text('Otorgado a 42 usuarios.'), findsOneWidget);
  });

  testWidgets('cancelar el diálogo de evento no llama al repositorio', (tester) async {
    await _growSurface(tester);
    final repo = FakeAdminCoinsRepository();
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Monto (coins) por usuario'), '100');
    await tester.tap(find.text('LANZAR EVENTO A TODA LA COMUNIDAD'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.calls, isNot(contains('broadcast(100)')));
  });

  testWidgets('muestra el historial, distinguiendo otorgamientos individuales de broadcasts',
      (tester) async {
    await _growSurface(tester);
    final repo = FakeAdminCoinsRepository(history: [
      CoinGrantEntity(
        id: '1',
        grantedByUsername: 'lionheartsq',
        targetUsername: null,
        amount: 100,
        reason: 'evento de lanzamiento',
        recipientCount: 5,
        createdAt: DateTime(2026, 7, 18),
      ),
      CoinGrantEntity(
        id: '2',
        grantedByUsername: 'lionheartsq',
        targetUsername: 'squall',
        amount: 500,
        reason: 'premio',
        recipientCount: null,
        createdAt: DateTime(2026, 7, 17),
      ),
    ]);
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    expect(find.text('+100 → Comunidad (5 usuarios)'), findsOneWidget);
    expect(find.text('+500 → squall'), findsOneWidget);
  });
}
