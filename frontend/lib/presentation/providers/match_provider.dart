import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/repositories/match_repository_impl.dart';
import '../../domain/entities/attack_event.dart';
import '../../domain/entities/match_state.dart';
import '../../domain/repositories/match_repository.dart';

enum MatchPhase { idle, connecting, queued, matchFound, inProgress, over, fatalError }

class MatchUiState {
  final MatchPhase phase;
  final String? opponentUsername;
  final MatchStateEntity? state;
  final String? winnerUserId;
  final String? matchOverReason;
  final String? errorMessage;

  /// Se incrementa en cada mensaje `error` del servidor, incluso si el
  /// texto es idéntico al anterior — sin esto, dos rechazos consecutivos
  /// con el mismo `detail` (ej. tocar dos veces una acción inválida) se ven
  /// como "el mismo" error para un listener que compara por igualdad de
  /// `errorMessage`, y el segundo aviso nunca se muestra.
  final int errorNonce;

  /// Ataques resueltos que llegaron junto con el `state_update`/`match_over`
  /// más reciente — MatchPage los consume para animarlos en secuencia. Se
  /// mandan agrupados con el nuevo estado (no apenas llega cada
  /// `attack_event`) para que la UI pueda decidir sola cuándo mostrar el
  /// resultado final, después de la animación, en vez de que el tablero
  /// salte instantáneamente por delante de la animación.
  final List<AttackEventEntity> pendingEvents;

  /// Mismo motivo que `errorNonce`: un batch nuevo de eventos vacío (ej.
  /// jugar una carta, sin ataques) igual tiene que poder distinguirse del
  /// batch anterior si por casualidad también estaba vacío.
  final int eventBatchNonce;

  const MatchUiState({
    this.phase = MatchPhase.idle,
    this.opponentUsername,
    this.state,
    this.winnerUserId,
    this.matchOverReason,
    this.errorMessage,
    this.errorNonce = 0,
    this.pendingEvents = const [],
    this.eventBatchNonce = 0,
  });

  /// `errorMessage` es intencionalmente el único campo que SIEMPRE se
  /// reemplaza (no se preserva si no se pasa) — es un aviso transitorio de
  /// la última acción rechazada por el servidor, no algo que deba
  /// sobrevivir al próximo mensaje. Los demás campos son acumulativos
  /// dentro de una misma conexión (match_found no pisa el estado de
  /// partida que llegue después, etc.).
  MatchUiState copyWith({
    MatchPhase? phase,
    String? opponentUsername,
    MatchStateEntity? state,
    String? winnerUserId,
    String? matchOverReason,
    String? errorMessage,
    int? errorNonce,
    List<AttackEventEntity>? pendingEvents,
    int? eventBatchNonce,
  }) {
    return MatchUiState(
      phase: phase ?? this.phase,
      opponentUsername: opponentUsername ?? this.opponentUsername,
      state: state ?? this.state,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      matchOverReason: matchOverReason ?? this.matchOverReason,
      errorMessage: errorMessage,
      errorNonce: errorNonce ?? this.errorNonce,
      pendingEvents: pendingEvents ?? this.pendingEvents,
      eventBatchNonce: eventBatchNonce ?? this.eventBatchNonce,
    );
  }
}

final matchRepositoryProvider = Provider<MatchRepository>((ref) => MatchRepositoryImpl());

class MatchNotifier extends Notifier<MatchUiState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  /// Ataques ya llegados pero todavía no adjuntados a un state_update/
  /// match_over -- el protocolo manda cada attack_event como su propio
  /// mensaje, en orden, antes del snapshot que ya refleja el resultado.
  final List<AttackEventEntity> _bufferedEvents = [];

  @override
  MatchUiState build() {
    // `ref.read` no se puede llamar DENTRO del callback de onDispose (lo
    // prohíbe Riverpod) — hay que capturar la referencia acá, mientras el
    // provider todavía está "vivo".
    final repository = ref.read(matchRepositoryProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      repository.disconnect();
    });
    return const MatchUiState();
  }

  MatchRepository get _repository => ref.read(matchRepositoryProvider);

  Future<void> startQueue(List<String> deck) => _connectAndSend(() => _repository.queue(deck));

  /// Arranca al toque contra el bot de práctica, sin pasar por la cola de
  /// matchmaking real — mismo protocolo de mensajes que un emparejamiento
  /// real (`match_found`/`state_update`), así que el resto de este
  /// notifier y de MatchPage no necesitan saber que el rival es un bot.
  Future<void> startBotMatch(List<String> deck) =>
      _connectAndSend(() => _repository.startBotMatch(deck));

  Future<void> _connectAndSend(void Function() sendInitialAction) async {
    state = const MatchUiState(phase: MatchPhase.connecting);
    try {
      final stream = await _repository.connect();
      await _subscription?.cancel();
      _subscription = stream.listen(
        _handleMessage,
        onError: (_) => _fail('Se perdió la conexión con el servidor.'),
        onDone: () {
          if (state.phase != MatchPhase.over) {
            // Un cierre con código 4401 es el servidor rechazando el JWT
            // (vencido o inválido) al conectar — mensaje específico en vez
            // del genérico, para que el jugador sepa que tiene que volver a
            // iniciar sesión en vez de solo "reintentar".
            _fail(
              _repository.lastCloseCode == 4401
                  ? 'Tu sesión expiró. Iniciá sesión de nuevo.'
                  : 'La conexión se cerró inesperadamente.',
            );
          }
        },
      );
      sendInitialAction();
    } on ApiException catch (e) {
      state = MatchUiState(phase: MatchPhase.fatalError, errorMessage: e.message);
    } catch (_) {
      _fail('No se pudo conectar al servidor.');
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    // Un mensaje del servidor con una forma inesperada (campo faltante,
    // tipo distinto) no debe tirar una excepción no capturada — Dart NO
    // rutea las excepciones sincrónicas de `onData` al `onError` de la
    // misma suscripción, así que sin este try/catch la UI queda colgada
    // para siempre sin ningún error visible.
    try {
      switch (message['type']) {
        case 'queued':
          state = state.copyWith(phase: MatchPhase.queued);
          break;
        case 'match_found':
          state = state.copyWith(
            phase: MatchPhase.matchFound,
            opponentUsername: message['opponent_username'] as String,
          );
          break;
        case 'attack_event':
          _bufferedEvents.add(AttackEventEntity.fromJson(message));
          break;
        case 'state_update':
          state = state.copyWith(
            phase: MatchPhase.inProgress,
            state: MatchStateEntity.fromJson(message['state'] as Map<String, dynamic>),
            pendingEvents: _drainBufferedEvents(),
            eventBatchNonce: state.eventBatchNonce + 1,
          );
          break;
        case 'match_over':
          state = state.copyWith(
            phase: MatchPhase.over,
            winnerUserId: message['winner_user_id'] as String?,
            matchOverReason: message['reason'] as String?,
            pendingEvents: _drainBufferedEvents(),
            eventBatchNonce: state.eventBatchNonce + 1,
          );
          break;
        case 'error':
          state = state.copyWith(
            errorMessage: message['detail'] as String?,
            errorNonce: state.errorNonce + 1,
          );
          break;
      }
    } catch (_) {
      _fail('Se recibió un mensaje inválido del servidor.');
    }
  }

  List<AttackEventEntity> _drainBufferedEvents() {
    final events = List<AttackEventEntity>.from(_bufferedEvents);
    _bufferedEvents.clear();
    return events;
  }

  void _fail(String message) {
    state = state.copyWith(phase: MatchPhase.fatalError, errorMessage: message);
  }

  void playCard(String playerCardId) => _repository.playCard(playerCardId);
  void attackFace(String attackerId) => _repository.attackFace(attackerId);
  void attackCard({required String attackerId, required String targetCardId}) =>
      _repository.attackCard(attackerId: attackerId, targetCardId: targetCardId);
  void endTurn() => _repository.endTurn();
  void forfeit() => _repository.forfeit();

  Future<void> leaveAndReset() async {
    // Si todavía estamos esperando en la cola (no en una partida), mandar
    // el `leave_queue` explícito antes de cortar la conexión del todo —
    // sin esto, ese camino del protocolo queda sin usar y "Cancelar"
    // siempre depende de la desconexión implícita del servidor.
    if (state.phase == MatchPhase.connecting || state.phase == MatchPhase.queued) {
      _repository.leaveQueue();
    }
    await _subscription?.cancel();
    _subscription = null;
    await _repository.disconnect();
    state = const MatchUiState();
  }
}

final matchNotifierProvider = NotifierProvider<MatchNotifier, MatchUiState>(MatchNotifier.new);
