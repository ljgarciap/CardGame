import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/owned_card.dart';
import '../providers/collection_provider.dart';
import '../widgets/game_card_widget.dart';
import 'matchmaking_page.dart';

/// Tamaño de mazo — regla de juego fija (igual que `DECK_SIZE` en
/// `match_engine.py`), no un valor de negocio configurable, así que vive
/// como constante acá en vez de en una tabla paramétrica.
const int _deckSize = 10;

class DeckBuilderPage extends ConsumerStatefulWidget {
  const DeckBuilderPage({super.key});

  @override
  ConsumerState<DeckBuilderPage> createState() => _DeckBuilderPageState();
}

class _DeckBuilderPageState extends ConsumerState<DeckBuilderPage> {
  late Future<List<OwnedCardEntity>> _cardsFuture;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  void _loadCards() {
    _cardsFuture = ref.read(collectionRepositoryProvider).getMyCards();
  }

  Future<void> _reload() async {
    setState(_loadCards);
    await _cardsFuture;
  }

  void _toggle(String playerCardId) {
    setState(() {
      if (_selected.contains(playerCardId)) {
        _selected.remove(playerCardId);
      } else if (_selected.length < _deckSize) {
        _selected.add(playerCardId);
      }
    });
  }

  void _confirmDeck() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MatchmakingPage(deck: _selected.toList())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ARMÁ TU MAZO', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B0E3A), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: FutureBuilder<List<OwnedCardEntity>>(
                    future: _cardsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
                        );
                      }
                      if (snapshot.hasError) {
                        final message = snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'No se pudo cargar tu colección.';
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _reload, child: const Text('Reintentar')),
                            ],
                          ),
                        );
                      }

                      final cards = snapshot.data!;
                      if (cards.isEmpty) {
                        return const Center(
                          child: Text(
                            'Todavía no tenés cartas.\nAbrí un sobre en el Marketplace.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      // GameCardWidget usa un ancho fijo (default 250) para
                      // calcular su propio `scale` interno — sin pasarle el
                      // ancho real de la celda, se renderiza a 250 sin
                      // importar cuánto mida la grilla, y desborda en
                      // cualquier pantalla angosta (el caso normal en
                      // celular, no solo un extremo).
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const crossAxisCount = 2;
                          const crossAxisSpacing = 16.0;
                          final cardWidth =
                              (constraints.maxWidth - crossAxisSpacing * (crossAxisCount - 1)) /
                                  crossAxisCount;

                          return GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];
                              return GameCardWidget(
                                name: card.name,
                                faction: card.faction,
                                rank: card.rank,
                                rarity: card.rarity,
                                attack: card.attack,
                                defense: card.defense,
                                width: cardWidth,
                                selected: _selected.contains(card.playerCardId),
                                onTap: () => _toggle(card.playerCardId),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Text(
                      '${_selected.length}/$_deckSize',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _selected.length == _deckSize ? _confirmDeck : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        'BUSCAR PARTIDA',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
