import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/card.dart';
import 'dart:math';

class PackOpeningPage extends StatefulWidget {
  final CardPackEntity pack;

  const PackOpeningPage({super.key, required this.pack});

  @override
  State<PackOpeningPage> createState() => _PackOpeningPageState();
}

class _PackOpeningPageState extends State<PackOpeningPage> {
  bool _isOpened = false;
  List<TCGCardEntity> _revealedCards = [];

  void _openPack() {
    setState(() {
      _isOpened = true;
      // Simulate generating 5 cards based on probabilities
      _revealedCards = List.generate(5, (index) => _generateRandomCard());
    });
  }

  TCGCardEntity _generateRandomCard() {
    // Basic random logic for demo
    final random = Random();
    final rarityValue = random.nextDouble();
    CardRarity rarity = CardRarity.common;
    if (rarityValue < 0.05) rarity = CardRarity.legendary;
    else if (rarityValue < 0.15) rarity = CardRarity.epic;
    else if (rarityValue < 0.40) rarity = CardRarity.rare;

    return TCGCardEntity(
      id: random.nextInt(1000).toString(),
      name: 'God Prototype',
      faction: CardFaction.values[random.nextInt(CardFaction.values.length)],
      rarity: rarity,
      rank: CardRank.values[random.nextInt(CardRank.values.length)],
      attack: 10 + random.nextInt(90),
      defense: 10 + random.nextInt(90),
      description: 'A powerful deity from ancient times.',
    );
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
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: _openPack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('OPEN PACK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
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
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: _TCGCardWidget(card: _revealedCards[index])
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
          onPressed: () => setState(() => _isOpened = false),
          child: const Text('OPEN ANOTHER', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

class _TCGCardWidget extends StatelessWidget {
  final TCGCardEntity card;

  const _TCGCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    final color = _getRarityColor(card.rarity);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(card.rank.name.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                FaIcon(FontAwesomeIcons.bolt, size: 12, color: color),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: FaIcon(FontAwesomeIcons.userAstronaut, size: 80, color: Colors.white24),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 5),
                Text(card.faction.name.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Stat(label: 'ATK', value: card.attack, color: Colors.red),
                    _Stat(label: 'DEF', value: card.defense, color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common: return Colors.grey;
      case CardRarity.rare: return Colors.blue;
      case CardRarity.epic: return Colors.purple;
      case CardRarity.legendary: return Colors.amber;
    }
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
