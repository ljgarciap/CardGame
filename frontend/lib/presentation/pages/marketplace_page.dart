import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/card.dart';
import 'pack_opening_page.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final packs = [
      CardPackEntity(id: '1', name: 'Mortal Pack', level: PackLevel.level1()),
      CardPackEntity(id: '2', name: 'Heroic Pack', level: PackLevel(
        level: 2, 
        rankProbabilities: {CardRank.hero: 0.60, CardRank.demigod: 0.30, CardRank.minorGod: 0.08, CardRank.majorGod: 0.02},
        rarityProbabilities: {CardRarity.common: 0.70, CardRarity.rare: 0.20, CardRarity.epic: 0.08, CardRarity.legendary: 0.02},
      )),
      CardPackEntity(id: '5', name: 'Godly Pack', level: PackLevel.level5()),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MARKETPLACE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
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
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: packs.length,
                  itemBuilder: (context, index) {
                    return _PackCard(pack: packs[index]).animate(delay: (index * 100).ms).scale().fadeIn();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final CardPackEntity pack;

  const _PackCard({required this.pack});

  @override
  Widget build(BuildContext context) {
    final color = _getPackColor(pack.level.level);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PackOpeningPage(pack: pack)),
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
                if (pack.level.level == 5)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: FaIcon(FontAwesomeIcons.crown, color: Colors.amber, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              pack.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'LEVEL ${pack.level.level}',
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
                    '${pack.level.level * 1000}',
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
