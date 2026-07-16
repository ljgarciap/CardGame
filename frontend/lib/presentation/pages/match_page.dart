import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _leaveMatch() async {
    // Esperar a que leaveAndReset() termine (cancela la suscripción y
    // cierra la conexión) antes de salir de la pantalla — si no, un
    // re-encolado rápido podría arrancar una conexión nueva mientras esta
    // limpieza todavía está en vuelo.
    await ref.read(matchNotifierProvider.notifier).leaveAndReset();
    if (mounted) Navigator.of(context).pop();
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
      if (next.phase == MatchPhase.over && previous?.phase != MatchPhase.over) {
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
        _cardRow(state.opponentBoard, height: 170, onTap: targeting ? _attackCard : null),
        const Divider(color: Colors.white12, height: 24),
        _turnBanner(state),
        const Spacer(),
        _cardRow(
          state.yourBoard,
          height: 190,
          onTap: (card) => _selectAttacker(card, state.yourTurn),
          selectedId: _selectedAttackerId,
        ),
        const SizedBox(height: 8),
        _cardRow(
          state.yourHand,
          height: 190,
          onTap: state.yourTurn ? _playCard : null,
        ),
        _yourInfo(state),
      ],
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
          GestureDetector(
            onTap: targeting ? _attackFace : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: targeting ? Colors.redAccent.withValues(alpha: 0.25) : Colors.black26,
                borderRadius: BorderRadius.circular(20),
                border: targeting ? Border.all(color: Colors.redAccent, width: 2) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text('${state.opponentLife}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
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
          const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text('${state.yourLife}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('Mazo: ${state.yourDeckCount}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => ref.read(matchNotifierProvider.notifier).forfeit(),
            child: const Text('Rendirse', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: state.yourTurn
                ? () {
                    ref.read(matchNotifierProvider.notifier).endTurn();
                    setState(() => _selectedAttackerId = null);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Terminar turno'),
          ),
        ],
      ),
    );
  }

  Widget _turnBanner(MatchStateEntity state) {
    return Text(
      state.yourTurn ? 'TU TURNO' : 'TURNO DEL RIVAL',
      style: TextStyle(
        color: state.yourTurn ? Colors.greenAccent : Colors.white38,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  Widget _cardRow(
    List<CardInPlayEntity> cards, {
    required double height,
    void Function(CardInPlayEntity card)? onTap,
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
            ),
          );
        },
      ),
    );
  }
}
