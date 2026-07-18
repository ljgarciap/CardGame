import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/card.dart';
import '../providers/auth_provider.dart';
import '../providers/pack_provider.dart';
import '../widgets/game_card_widget.dart';

class PackOpeningPage extends ConsumerStatefulWidget {
  final int level;

  const PackOpeningPage({super.key, required this.level});

  @override
  ConsumerState<PackOpeningPage> createState() => _PackOpeningPageState();
}

class _PackOpeningPageState extends ConsumerState<PackOpeningPage> {
  bool _isOpened = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<TCGCardEntity> _revealedCards = [];

  Future<void> _openPack() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(packRepositoryProvider)
          .openPack(level: widget.level);
      setState(() {
        _revealedCards = result.cards;
        _isOpened = true;
        _isLoading = false;
      });
      // El saldo ya se descontó en el servidor; refrescamos el perfil
      // cacheado (ProfilePage lo muestra) sin bloquear la revelación.
      unawaited(ref.read(authNotifierProvider.notifier).refreshProfile());
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      // Red caída, respuesta no-JSON, valor de enum desconocido, etc. — sin
      // esto el botón quedaba deshabilitado para siempre (_isLoading nunca
      // se resetea) y el usuario no tenía forma de reintentar. El mensaje
      // al usuario queda genérico a propósito, pero se loguea el error real
      // -- un ArgumentError de CardFaction.values.byName() por un valor de
      // enum nuevo que el backend ya manda y el frontend todavía no conoce
      // (pasó de verdad con "muisca") no debería quedar invisible del todo.
      debugPrint('PackOpeningPage._openPack error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo abrir el sobre. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_isOpened)
              _buildClosedPack()
            else
              _buildRevealedCards(),

            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedPack() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const FaIcon(
          FontAwesomeIcons.boxOpen,
          size: 150,
          color: Colors.amber,
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: -20, end: 20, duration: 2.seconds, curve: Curves.easeInOut)
          .shimmer(duration: 3.seconds, color: Colors.white),
        const SizedBox(height: 30),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _openPack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                )
              : const Text('OPEN PACK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        ).animate().scale(delay: 500.ms),
      ],
    );
  }

  Widget _buildRevealedCards() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 400,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _revealedCards.length,
            padding: const EdgeInsets.symmetric(horizontal: 50),
            itemBuilder: (context, index) {
              final card = _revealedCards[index];
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: GameCardWidget(
                  name: card.name,
                  faction: card.faction,
                  rank: card.rank,
                  rarity: card.rarity,
                  attack: card.attack,
                  defense: card.defense,
                )
                  .animate(delay: (index * 300).ms)
                  .flipH()
                  .fadeIn()
                  .shimmer(delay: (index * 300 + 500).ms),
              );
            },
          ),
        ),
        const SizedBox(height: 50),
        TextButton(
          onPressed: () => setState(() {
            _isOpened = false;
            _errorMessage = null;
          }),
          child: const Text('OPEN ANOTHER', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
