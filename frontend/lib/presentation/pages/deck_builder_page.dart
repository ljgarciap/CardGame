import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/owned_card.dart';
import '../providers/collection_provider.dart';
import '../providers/deck_provider.dart';
import '../widgets/game_card_widget.dart';

/// Tamaño de mazo — regla de juego fija (igual que `DECK_SIZE` en
/// `match_engine.py`), no un valor de negocio configurable, así que vive
/// como constante acá en vez de en una tabla paramétrica.
const int _deckSize = 10;

/// Crea o edita un mazo guardado — ya no arma-y-encola directo (eso ahora
/// pasa por [MyDecksPage], que entra a matchmaking con un mazo ya
/// guardado). Con `deckId` null es "crear nuevo"; con `deckId` seteado es
/// "editar", precargado con `initialName`/`initialCardIds`.
class DeckBuilderPage extends ConsumerStatefulWidget {
  final String? deckId;
  final String? initialName;
  final Set<String>? initialCardIds;

  const DeckBuilderPage({
    super.key,
    this.deckId,
    this.initialName,
    this.initialCardIds,
  });

  bool get isEditing => deckId != null;

  @override
  ConsumerState<DeckBuilderPage> createState() => _DeckBuilderPageState();
}

class _DeckBuilderPageState extends ConsumerState<DeckBuilderPage> {
  late Future<List<OwnedCardEntity>> _cardsFuture;
  late final Set<String> _selected;
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = {...?widget.initialCardIds};
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _loadCards();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  bool get _canSave => _selected.length == _deckSize && _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repository = ref.read(deckRepositoryProvider);
      final name = _nameController.text.trim();
      if (widget.isEditing) {
        await repository.updateDeck(deckId: widget.deckId!, name: name, playerCardIds: _selected.toList());
      } else {
        await repository.createDeck(name: name, playerCardIds: _selected.toList());
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el mazo. Intentá de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'EDITAR MAZO' : 'NUEVO MAZO',
          style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold),
        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del mazo',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
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
                      onPressed: _canSave && !_saving ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'GUARDAR',
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
