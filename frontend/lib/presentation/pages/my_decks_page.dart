import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/saved_deck.dart';
import '../providers/deck_provider.dart';
import 'deck_builder_page.dart';
import 'matchmaking_page.dart';

/// Hub del flujo de multijugador: lista los mazos guardados del jugador.
/// Jugar entra directo a matchmaking con ese mazo; Editar/Nuevo abren
/// DeckBuilderPage en modo edición/creación.
class MyDecksPage extends ConsumerStatefulWidget {
  const MyDecksPage({super.key});

  @override
  ConsumerState<MyDecksPage> createState() => _MyDecksPageState();
}

class _MyDecksPageState extends ConsumerState<MyDecksPage> {
  late Future<List<SavedDeckEntity>> _decksFuture;

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  void _loadDecks() {
    _decksFuture = ref.read(deckRepositoryProvider).getDecks();
  }

  Future<void> _reload() async {
    setState(_loadDecks);
    await _decksFuture;
  }

  Future<void> _createNew() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DeckBuilderPage()),
    );
    _reload();
  }

  Future<void> _edit(SavedDeckEntity deck) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeckBuilderPage(
          deckId: deck.id,
          initialName: deck.name,
          initialCardIds: deck.cards.map((c) => c.playerCardId).toSet(),
        ),
      ),
    );
    _reload();
  }

  Future<void> _delete(SavedDeckEntity deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('¿Eliminar mazo?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se va a borrar "${deck.name}" para siempre.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(deckRepositoryProvider).deleteDeck(deck.id);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _play(SavedDeckEntity deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MatchmakingPage(deck: deck.cards.map((c) => c.playerCardId).toList()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MIS MAZOS', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold)),
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
                  child: FutureBuilder<List<SavedDeckEntity>>(
                    future: _decksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
                        );
                      }
                      if (snapshot.hasError) {
                        final message = snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'No se pudieron cargar tus mazos.';
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

                      final decks = snapshot.data!;
                      if (decks.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Todavía no tenés mazos guardados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _createNew,
                                child: const Text('Crear mi primer mazo'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: decks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _DeckTile(
                          deck: decks[index],
                          onPlay: () => _play(decks[index]),
                          onEdit: () => _edit(decks[index]),
                          onDelete: () => _delete(decks[index]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _createNew,
                    icon: const Icon(Icons.add),
                    label: const Text('NUEVO MAZO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final SavedDeckEntity deck;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeckTile({
    required this.deck,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deck.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${deck.cards.length} cartas', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPlay,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  child: const Text('JUGAR'),
                ),
              ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.white54)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }
}
