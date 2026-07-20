import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/attack_event.dart';
import '../../domain/entities/match_state.dart';
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../widgets/game_card_widget.dart';

class MatchPage extends ConsumerStatefulWidget {
  const MatchPage({super.key});

  @override
  ConsumerState<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends ConsumerState<MatchPage> {
  String? _selectedAttackerId;

  /// Texto del último ataque resuelto, mostrado unos segundos -- sin esto
  /// no hay ninguna señal visual de "quién le pegó a quién" más allá del
  /// número de vida cambiando solo, que además puede pasar desapercibido
  /// (ver docs/memory.md 2026-07-20).
  String? _combatLogText;
  bool _flashYourLife = false;
  bool _flashOpponentLife = false;

  void _selectAttacker(CardInPlayEntity card, bool yourTurn) {
    if (!yourTurn) return;
    if (card.summoningSick ?? false) {
      _showBriefMessage('Esa carta tiene mareo de invocación — no puede atacar todavía.');
      return;
    }
    if (card.hasAttackedThisTurn ?? false) {
      _showBriefMessage('Esa carta ya atacó este turno.');
      return;
    }
    setState(() {
      _selectedAttackerId = _selectedAttackerId == card.playerCardId ? null : card.playerCardId;
    });
  }

  void _showBriefMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _attackFace() {
    final attackerId = _selectedAttackerId;
    if (attackerId == null) return;
    ref.read(matchNotifierProvider.notifier).attackFace(attackerId);
    setState(() => _selectedAttackerId = null);
  }

  void _attackCard(CardInPlayEntity target) {
    final attackerId = _selectedAttackerId;
    if (attackerId == null) return;
    ref
        .read(matchNotifierProvider.notifier)
        .attackCard(attackerId: attackerId, targetCardId: target.playerCardId);
    setState(() => _selectedAttackerId = null);
  }

  void _playCard(CardInPlayEntity card) {
    ref.read(matchNotifierProvider.notifier).playCard(card.playerCardId);
  }

  void _showCardDetail(CardInPlayEntity card) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // GameCardWidget necesita una altura acotada del padre (tiene un
            // Expanded adentro para el ícono central) -- en _cardRow se la
            // da el SizedBox del ListView horizontal; acá, sin un SizedBox
            // explícito, Dialog + Column(mainAxisSize: min) le pasan altura
            // sin acotar y explota el layout (encontrado con un test real,
            // no era solo cosmético).
            SizedBox(
              height: 400,
              child: GameCardWidget(
                name: card.name,
                faction: card.faction,
                rank: card.rank,
                rarity: card.rarity,
                attack: card.attack,
                defense: card.currentDefense ?? card.maxDefense,
                width: 280,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CERRAR', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveMatch() async {
    // Esperar a que leaveAndReset() termine (cancela la suscripción y
    // cierra la conexión) antes de salir de la pantalla — si no, un
    // re-encolado rápido podría arrancar una conexión nueva mientras esta
    // limpieza todavía está en vuelo.
    await ref.read(matchNotifierProvider.notifier).leaveAndReset();
    if (mounted) Navigator.of(context).pop();
  }

  String _describeEvent(AttackEventEntity event, bool iAttacked) {
    if (event.isFaceAttack) {
      final target = iAttacked ? 'la vida rival' : 'tu vida';
      return '${event.attackerName} ataca directo a $target (-${event.damage})';
    }
    final suffix = event.targetDefeated ? ' ¡destruida!' : '';
    return '${event.attackerName} ataca a ${event.targetName ?? 'una carta'} (-${event.damage})$suffix';
  }

  /// Muestra cada ataque del batch en secuencia (el bot puede atacar con
  /// varias cartas en un mismo turno) antes de aplicar el resultado final
  /// visualmente ya asentado — si el batch cierra la partida, el diálogo de
  /// resultado se muestra recién después de terminar de animar, para que no
  /// tape el golpe que la decidió.
  Future<void> _playEventSequence(List<AttackEventEntity> events, {MatchUiState? showResultAfter}) async {
    final myId = ref.read(authNotifierProvider).user?.id;
    for (final event in events) {
      if (!mounted) return;
      final iAttacked = event.attackingPlayerId == myId;
      setState(() {
        _combatLogText = _describeEvent(event, iAttacked);
        if (event.isFaceAttack) {
          if (iAttacked) {
            _flashOpponentLife = true;
          } else {
            _flashYourLife = true;
          }
        }
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _flashYourLife = false;
        _flashOpponentLife = false;
      });
    }
    if (!mounted) return;
    setState(() => _combatLogText = null);
    if (showResultAfter != null) {
      _showResultDialog(showResultAfter);
    }
  }

  void _showResultDialog(MatchUiState uiState) {
    final myId = ref.read(authNotifierProvider).user?.id;
    final won = uiState.winnerUserId != null && uiState.winnerUserId == myId;
    final reasonLabel = switch (uiState.matchOverReason) {
      'life_zero' => 'por vida a cero',
      'fatigue' => 'por fatiga (mazo vacío)',
      'forfeit' => 'por rendición',
      'disconnect' => 'el rival se desconectó',
      _ => '',
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          won ? '¡VICTORIA!' : 'DERROTA',
          style: TextStyle(
            color: won ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: Text(reasonLabel, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // cierra el diálogo
              _leaveMatch();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _showFatalErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Conexión perdida', style: TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _leaveMatch();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MatchUiState>(matchNotifierProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.redAccent),
        );
      }
      final newEventBatch =
          next.eventBatchNonce != previous?.eventBatchNonce && next.pendingEvents.isNotEmpty;
      if (newEventBatch) {
        _playEventSequence(
          next.pendingEvents,
          showResultAfter: next.phase == MatchPhase.over ? next : null,
        );
      } else if (next.phase == MatchPhase.over && previous?.phase != MatchPhase.over) {
        _showResultDialog(next);
      }
      if (next.phase == MatchPhase.fatalError && previous?.phase != MatchPhase.fatalError) {
        _showFatalErrorDialog(next.errorMessage ?? 'Se perdió la conexión.');
      }
    });

    final uiState = ref.watch(matchNotifierProvider);
    final matchState = uiState.state;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) ref.read(matchNotifierProvider.notifier).leaveAndReset();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B0E3A), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: matchState == null
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                : _buildBoard(matchState, uiState),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(MatchStateEntity state, MatchUiState uiState) {
    // Gateado por yourTurn (no alcanza con limpiar _selectedAttackerId al
    // terminar turno — el turno también puede cambiar por otras vías, ej.
    // un state_update que llega mientras el jugador todavía no actuó) y
    // por que la carta seleccionada siga realmente en el tablero (pudo
    // haber sido destruida). Sin este doble chequeo, un ataque queda
    // "armado" contra un rival fuera de turno o referenciando una carta
    // que ya no existe.
    final attackerStillOnBoard =
        _selectedAttackerId != null && state.yourBoard.any((c) => c.playerCardId == _selectedAttackerId);
    final targeting = attackerStillOnBoard && state.yourTurn;

    return Column(
      children: [
        _opponentInfo(state, uiState.opponentUsername, targeting),
        _cardRow(
          state.opponentBoard,
          height: 170,
          onTap: targeting ? _attackCard : null,
          onLongPress: _showCardDetail,
        ),
        const Divider(color: Colors.white12, height: 24),
        _turnBanner(state),
        _combatLog(),
        const Spacer(),
        _cardRow(
          state.yourBoard,
          height: 190,
          onTap: (card) => _selectAttacker(card, state.yourTurn),
          onLongPress: _showCardDetail,
          selectedId: _selectedAttackerId,
        ),
        const SizedBox(height: 8),
        _cardRow(
          state.yourHand,
          height: 190,
          onTap: state.yourTurn ? _playCard : null,
          onLongPress: _showCardDetail,
        ),
        _yourInfo(state),
      ],
    );
  }

  Widget _combatLog() {
    final text = _combatLogText;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox(height: 28)
          : Padding(
              key: ValueKey(text),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ).animate().fadeIn(duration: 150.ms),
            ),
    );
  }

  Widget _lifePill({required int life, required bool flashing, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: flashing
              ? Colors.redAccent.withValues(alpha: 0.6)
              : (onTap != null ? Colors.redAccent.withValues(alpha: 0.25) : Colors.black26),
          borderRadius: BorderRadius.circular(20),
          border: onTap != null ? Border.all(color: Colors.redAccent, width: 2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
            const SizedBox(width: 6),
            Text('$life', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _opponentInfo(MatchStateEntity state, String? opponentUsername, bool targeting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            opponentUsername ?? 'Rival',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text('Mazo: ${state.opponentDeckCount}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 12),
          Text('Mano: ${state.opponentHandCount}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 16),
          _lifePill(
            life: state.opponentLife,
            flashing: _flashOpponentLife,
            onTap: targeting ? _attackFace : null,
          ),
        ],
      ),
    );
  }

  Widget _yourInfo(MatchStateEntity state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _lifePill(life: state.yourLife, flashing: _flashYourLife, onTap: null),
          const Spacer(),
          Text('Mazo: ${state.yourDeckCount}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => ref.read(matchNotifierProvider.notifier).forfeit(),
            child: const Text('Rendirse', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  /// Cuando es tu turno, el cartel ES el botón para terminarlo — antes
  /// había un botón chico separado abajo del todo, lejos de este cartel
  /// (que es justo donde mirás para saber de quién es el turno). Tenerlos
  /// juntos, en vez de en puntas opuestas de la pantalla, es lo que hace
  /// obvio cómo pasar de turno.
  Widget _turnBanner(MatchStateEntity state) {
    if (!state.yourTurn) {
      return const Text(
        'TURNO DEL RIVAL',
        style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2),
      );
    }

    return GestureDetector(
      onTap: () {
        ref.read(matchNotifierProvider.notifier).endTurn();
        setState(() => _selectedAttackerId = null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.greenAccent, width: 2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TU TURNO — TOCÁ PARA TERMINAR',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.greenAccent, size: 18),
          ],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _cardRow(
    List<CardInPlayEntity> cards, {
    required double height,
    void Function(CardInPlayEntity card)? onTap,
    void Function(CardInPlayEntity card)? onLongPress,
    String? selectedId,
  }) {
    if (cards.isEmpty) {
      return SizedBox(height: height, child: const Center(child: SizedBox.shrink()));
    }
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GameCardWidget(
              name: card.name,
              faction: card.faction,
              rank: card.rank,
              rarity: card.rarity,
              attack: card.attack,
              defense: card.currentDefense ?? card.maxDefense,
              width: height * 0.68,
              selected: card.playerCardId == selectedId,
              summoningSick: card.summoningSick ?? false,
              disabled: card.hasAttackedThisTurn ?? false,
              onTap: onTap == null ? null : () => onTap(card),
              onLongPress: onLongPress == null ? null : () => onLongPress(card),
            ),
          );
        },
      ),
    );
  }
}
