import 'package:card_game/domain/entities/card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TCGCardEntity.fromJson', () {
    Map<String, dynamic> buildJson({required String faction}) => {
          'archetype_id': 'archetype-1',
          'name': 'Bochica, the Civilizer',
          'faction': faction,
          'rarity': 'common',
          'rank': 'hero',
          'attack': 30,
          'defense': 30,
        };

    for (final faction in [
      'greek',
      'norse',
      'egyptian',
      'aztec',
      'oriental',
      'muisca',
    ]) {
      test('parsea faction "$faction" sin lanzar', () {
        final card = TCGCardEntity.fromJson(buildJson(faction: faction));
        expect(card.faction.name, faction);
      });
    }

    test('facción desconocida lanza (regresión: antes tiraba silenciosamente '
        'para "muisca" hasta que se agregó al enum del frontend)', () {
      expect(
        () => TCGCardEntity.fromJson(buildJson(faction: 'yoruba')),
        throwsArgumentError,
      );
    });
  });
}
