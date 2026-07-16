import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/entities/card.dart';

/// Widget de carta reusable — antes duplicado como `_TCGCardWidget` en
/// `pack_opening_page.dart`. Toma los campos sueltos en vez de una entidad
/// puntual porque lo usan tres orígenes de datos distintos con formas
/// parecidas pero no idénticas (`TCGCardEntity` del sobre, `OwnedCardEntity`
/// del deck builder, `CardInPlayEntity` del tablero de partida) — cada
/// caller extrae lo que tiene, sin acoplar el widget a una de las tres.
class GameCardWidget extends StatelessWidget {
  final String name;
  final CardFaction faction;
  final CardRank rank;
  final CardRarity rarity;
  final int attack;
  final int defense;
  final double width;
  final bool selected;
  final bool summoningSick;
  final VoidCallback? onTap;

  const GameCardWidget({
    super.key,
    required this.name,
    required this.faction,
    required this.rank,
    required this.rarity,
    required this.attack,
    required this.defense,
    this.width = 250,
    this.selected = false,
    this.summoningSick = false,
    this.onTap,
  });

  Color get _rarityColor {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey;
      case CardRarity.rare:
        return Colors.blue;
      case CardRarity.epic:
        return Colors.purple;
      case CardRarity.legendary:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor;
    final scale = width / 250;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: summoningSick ? 0.55 : 1.0,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected ? Colors.greenAccent : color,
                  width: selected ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 20 * scale, spreadRadius: 5 * scale),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(10 * scale),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rank.name.toUpperCase(),
                          style: TextStyle(fontSize: 10 * scale, color: color, fontWeight: FontWeight.bold),
                        ),
                        FaIcon(FontAwesomeIcons.bolt, size: 12 * scale, color: color),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FaIcon(FontAwesomeIcons.userAstronaut, size: 80 * scale, color: Colors.white24),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(15.0 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * scale),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 5 * scale),
                        Text(
                          faction.name.toUpperCase(),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12 * scale),
                        ),
                        const Divider(color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Stat(label: 'ATK', value: attack, color: Colors.red, scale: scale),
                            _Stat(label: 'DEF', value: defense, color: Colors.blue, scale: scale),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 16, color: Colors.black),
              ),
            ),
          if (summoningSick)
            Positioned(
              top: 8 * scale,
              left: 8 * scale,
              child: FaIcon(FontAwesomeIcons.moon, size: 14 * scale, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final double scale;

  const _Stat({required this.label, required this.value, required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12 * scale)),
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale)),
      ],
    );
  }
}
