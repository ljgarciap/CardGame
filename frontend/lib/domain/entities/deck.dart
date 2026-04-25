import 'dart:math';
import 'card.dart';

class DeckEntity {
  final List<CardEntity> cards;

  DeckEntity({required this.cards});

  factory DeckEntity.standard52() {
    final cards = <CardEntity>[];
    for (final suit in CardSuit.values) {
      for (final value in CardValue.values) {
        cards.add(CardEntity(suit: suit, value: value));
      }
    }
    return DeckEntity(cards: cards);
  }

  void shuffle() {
    cards.shuffle(Random());
  }

  CardEntity? draw() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }

  int get remaining => cards.length;
}
