import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/presentation/providers/match_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_match_repository.dart';

void main() {
  late FakeMatchRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeMatchRepository();
    container = ProviderContainer(
      overrides: [matchRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('startQueue conecta y manda la acción queue con el mazo', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a', 'b']);

    expect(repository.calls, contains('queue([a, b])'));
  });

  test('startBotMatch conecta y manda la acción start_bot_match con el mazo', () async {
    await container.read(matchNotifierProvider.notifier).startBotMatch(['a', 'b']);

    expect(repository.calls, contains('startBotMatch([a, b])'));
  });

  test('mensaje queued pasa a fase queued', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'queued'});
    await Future.delayed(Duration.zero);

    expect(container.read(matchNotifierProvider).phase, MatchPhase.queued);
  });

  test('match_found guarda el username del rival y cambia de fase', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'match_found', 'match_id': 'm1', 'opponent_username': 'bob'});
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.matchFound);
    expect(state.opponentUsername, 'bob');
  });

  test('state_update parsea el estado de la partida', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({
      'type': 'state_update',
      'state': {
        'your_turn': true,
        'your_life': 20,
        'opponent_life': 17,
        'your_hand': [],
        'your_board': [],
        'opponent_board': [],
        'opponent_hand_count': 3,
        'your_deck_count': 6,
        'opponent_deck_count': 5,
      },
    });
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.inProgress);
    expect(state.state!.yourTurn, true);
    expect(state.state!.opponentLife, 17);
  });

  test('match_over guarda ganador y motivo', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'match_over', 'winner_user_id': 'u1', 'reason': 'life_zero'});
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.over);
    expect(state.winnerUserId, 'u1');
    expect(state.matchOverReason, 'life_zero');
  });

  test('mensaje error no cambia de fase, solo el mensaje de error', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);

    repository.emit({'type': 'error', 'detail': 'no es tu turno'});
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.inProgress);
    expect(state.errorMessage, 'no es tu turno');
  });

  test('un error posterior sin errorMessage lo limpia', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'error', 'detail': 'no es tu turno'});
    await Future.delayed(Duration.zero);
    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);

    expect(container.read(matchNotifierProvider).errorMessage, isNull);
  });

  test('connect() lanzando ApiException pasa a fatalError con ese mensaje', () async {
    repository.connectError = ApiException(statusCode: 401, message: 'No autenticado');

    await container.read(matchNotifierProvider.notifier).startQueue(['a']);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.fatalError);
    expect(state.errorMessage, 'No autenticado');
  });

  test('un error del stream pasa a fatalError', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emitError(Exception('conexión perdida'));
    await Future.delayed(Duration.zero);

    expect(container.read(matchNotifierProvider).phase, MatchPhase.fatalError);
  });

  test('leaveAndReset desconecta y vuelve al estado inicial', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'queued'});
    await Future.delayed(Duration.zero);

    await container.read(matchNotifierProvider.notifier).leaveAndReset();

    expect(repository.disconnected, true);
    expect(container.read(matchNotifierProvider).phase, MatchPhase.idle);
  });

  test('leaveAndReset manda leave_queue si todavía está en cola', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'queued'});
    await Future.delayed(Duration.zero);

    await container.read(matchNotifierProvider.notifier).leaveAndReset();

    expect(repository.calls, contains('leaveQueue()'));
  });

  test('leaveAndReset NO manda leave_queue si ya está en una partida', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);

    await container.read(matchNotifierProvider.notifier).leaveAndReset();

    expect(repository.calls, isNot(contains('leaveQueue()')));
  });

  test('dos errores consecutivos con el mismo texto son eventos distintos (errorNonce)', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'error', 'detail': 'no es tu turno'});
    await Future.delayed(Duration.zero);
    final firstNonce = container.read(matchNotifierProvider).errorNonce;

    repository.emit({'type': 'error', 'detail': 'no es tu turno'});
    await Future.delayed(Duration.zero);
    final secondNonce = container.read(matchNotifierProvider).errorNonce;

    expect(secondNonce, isNot(firstNonce));
  });

  test('attack_event se guarda en buffer, no aparece hasta el próximo state_update', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({
      'type': 'attack_event',
      'attacking_player_id': 'u1',
      'attacker_id': 'c1',
      'attacker_name': 'Achilles',
      'target': 'face',
      'target_name': null,
      'damage': 5,
      'target_defeated': false,
    });
    await Future.delayed(Duration.zero);

    expect(container.read(matchNotifierProvider).pendingEvents, isEmpty);
  });

  test('pendingEvents se adjuntan al próximo state_update, en orden', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    Map<String, dynamic> event(String attacker) => {
          'type': 'attack_event',
          'attacking_player_id': 'u1',
          'attacker_id': attacker,
          'attacker_name': attacker,
          'target': 'face',
          'target_name': null,
          'damage': 3,
          'target_defeated': false,
        };
    repository.emit(event('c1'));
    repository.emit(event('c2'));
    await Future.delayed(Duration.zero);
    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.pendingEvents, hasLength(2));
    expect(state.pendingEvents[0].attackerId, 'c1');
    expect(state.pendingEvents[1].attackerId, 'c2');
  });

  test('el batch de eventos se vacía para el próximo state_update', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({
      'type': 'attack_event',
      'attacking_player_id': 'u1',
      'attacker_id': 'c1',
      'attacker_name': 'Achilles',
      'target': 'face',
      'target_name': null,
      'damage': 5,
      'target_defeated': false,
    });
    await Future.delayed(Duration.zero);
    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);
    final firstNonce = container.read(matchNotifierProvider).eventBatchNonce;

    repository.emit({'type': 'state_update', 'state': _minimalState()});
    await Future.delayed(Duration.zero);
    final state = container.read(matchNotifierProvider);

    expect(state.pendingEvents, isEmpty);
    expect(state.eventBatchNonce, isNot(firstNonce));
  });

  test('match_over también arrastra los eventos pendientes', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({
      'type': 'attack_event',
      'attacking_player_id': 'u1',
      'attacker_id': 'c1',
      'attacker_name': 'Achilles',
      'target': 'face',
      'target_name': null,
      'damage': 20,
      'target_defeated': false,
    });
    await Future.delayed(Duration.zero);
    repository.emit({'type': 'match_over', 'winner_user_id': 'u1', 'reason': 'life_zero'});
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.over);
    expect(state.pendingEvents, hasLength(1));
  });

  test('un mensaje con forma inesperada no crashea, pasa a fatalError', () async {
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);
    repository.emit({'type': 'state_update', 'state': 'no-es-un-mapa'});
    await Future.delayed(Duration.zero);

    expect(container.read(matchNotifierProvider).phase, MatchPhase.fatalError);
  });

  test('cierre con código 4401 (token vencido) da un mensaje específico', () async {
    repository.lastCloseCodeToReturn = 4401;
    await container.read(matchNotifierProvider.notifier).startQueue(['a']);

    repository.emitDone();
    await Future.delayed(Duration.zero);

    final state = container.read(matchNotifierProvider);
    expect(state.phase, MatchPhase.fatalError);
    expect(state.errorMessage, contains('sesión'));
  });

  test('playCard/attackFace/attackCard/endTurn/forfeit delegan al repositorio', () {
    final notifier = container.read(matchNotifierProvider.notifier);

    notifier.playCard('c1');
    notifier.attackFace('c1');
    notifier.attackCard(attackerId: 'c1', targetCardId: 'c2');
    notifier.endTurn();
    notifier.forfeit();

    expect(repository.calls, [
      'playCard(c1)',
      'attackFace(c1)',
      'attackCard(c1, c2)',
      'endTurn()',
      'forfeit()',
    ]);
  });
}

Map<String, dynamic> _minimalState() => {
      'your_turn': false,
      'your_life': 20,
      'opponent_life': 20,
      'your_hand': [],
      'your_board': [],
      'opponent_board': [],
      'opponent_hand_count': 0,
      'your_deck_count': 10,
      'opponent_deck_count': 10,
    };
