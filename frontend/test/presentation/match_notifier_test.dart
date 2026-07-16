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
