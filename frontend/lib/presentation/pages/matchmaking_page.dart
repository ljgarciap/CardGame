import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/match_provider.dart';
import 'match_page.dart';

class MatchmakingPage extends ConsumerStatefulWidget {
  final List<String> deck;

  /// true: arranca al toque contra el bot de práctica, sin cola real.
  final bool isBotMatch;

  const MatchmakingPage({super.key, required this.deck, this.isBotMatch = false});

  @override
  ConsumerState<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends ConsumerState<MatchmakingPage> {
  bool _navigatedToMatch = false;

  @override
  void initState() {
    super.initState();
    // No se puede leer/escribir un provider directo desde initState — se
    // difiere un tick con microtask, mismo patrón que usaría un
    // WidgetsBinding.instance.addPostFrameCallback.
    Future.microtask(() {
      final notifier = ref.read(matchNotifierProvider.notifier);
      widget.isBotMatch ? notifier.startBotMatch(widget.deck) : notifier.startQueue(widget.deck);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MatchUiState>(matchNotifierProvider, (previous, next) {
      if (next.phase == MatchPhase.matchFound && !_navigatedToMatch) {
        _navigatedToMatch = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MatchPage()),
        );
      }
    });

    final state = ref.watch(matchNotifierProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(matchNotifierProvider.notifier).leaveAndReset();
        }
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: state.phase == MatchPhase.fatalError
                    ? _buildError(context, state)
                    : _buildSearching(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSearching(BuildContext context) {
    return [
      const CircularProgressIndicator(color: Colors.deepPurpleAccent)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1.seconds),
      const SizedBox(height: 30),
      Text(
        widget.isBotMatch ? 'PREPARANDO PARTIDA...' : 'BUSCANDO PARTIDA...',
        style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
      const SizedBox(height: 40),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
      ),
    ];
  }

  List<Widget> _buildError(BuildContext context, MatchUiState state) {
    return [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          state.errorMessage ?? 'Ocurrió un error.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
    ];
  }
}
