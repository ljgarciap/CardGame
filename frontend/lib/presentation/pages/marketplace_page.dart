import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/entities/gacha_config.dart';
import '../providers/auth_provider.dart';
import '../providers/pack_provider.dart';
import '../widgets/async_future_view.dart';
import 'pack_opening_page.dart';

/// Nombres de sobre puramente decorativos — no es un valor de negocio (no
/// afecta precio/probabilidades/economía), así que vive como texto local en
/// vez de en la tabla paramétrica del backend.
const Map<int, String> _packDisplayNames = {
  1: 'Mortal Pack',
  2: 'Heroic Pack',
  3: 'Divine Pack',
  4: 'Titan Pack',
  5: 'Godly Pack',
};

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  late Future<List<GachaPackLevelConfig>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  void _loadLevels() {
    _levelsFuture = ref.read(packRepositoryProvider).getPackLevels();
  }

  Future<void> _reload() async {
    setState(_loadLevels);
    await _levelsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(authNotifierProvider).user?.coins;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MARKETPLACE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold)),
        actions: [
          if (coins != null)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.coins, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text('$coins', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEATURED PACKS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 2,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideX(),
                const SizedBox(height: 20),
                Expanded(
                  child: AsyncFutureView<List<GachaPackLevelConfig>>(
                    future: _levelsFuture,
                    onRetry: _reload,
                    loadingColor: Colors.amber,
                    errorFallbackMessage: 'No se pudieron cargar los sobres.',
                    builder: (context, levels) {
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          return _PackCard(level: levels[index])
                              .animate(delay: (index * 100).ms)
                              .scale()
                              .fadeIn();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final GachaPackLevelConfig level;

  const _PackCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _getPackColor(level.level);
    final name = _packDisplayNames[level.level] ?? 'Level ${level.level} Pack';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PackOpeningPage(level: level.level)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.boxOpen,
                  size: 60,
                  color: color,
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.5)),
                if (level.level == 5)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: FaIcon(FontAwesomeIcons.crown, color: Colors.amber, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'LEVEL ${level.level} · ${level.cardsPerPack} CARDS',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.coins, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    '${level.price}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Color _getPackColor(int level) {
    switch (level) {
      case 1: return Colors.blueGrey;
      case 2: return Colors.blue;
      case 3: return Colors.purple;
      case 4: return Colors.red;
      case 5: return Colors.amber;
      default: return Colors.white;
    }
  }
}
