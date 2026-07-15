import 'package:card_game/domain/entities/card.dart';
import 'package:card_game/domain/entities/gacha_config.dart';
import 'package:card_game/domain/repositories/gacha_config_repository.dart';

class FakeGachaConfigRepository implements GachaConfigRepository {
  GachaConfigEntity? configToReturn;
  Object? getConfigError;
  Object? updatePackLevelError;
  Object? updateRankProbabilitiesError;
  Object? updateRarityProbabilitiesError;
  Object? updateRarityBonusError;

  final List<String> calls = [];

  FakeGachaConfigRepository({this.configToReturn});

  @override
  Future<GachaConfigEntity> getConfig() async {
    if (getConfigError != null) throw getConfigError!;
    return configToReturn ?? _defaultConfig();
  }

  @override
  Future<void> updatePackLevel({
    required int level,
    required int price,
    required int cardsPerPack,
    required CardRank? guaranteedMinRank,
  }) async {
    calls.add('updatePackLevel($level)');
    if (updatePackLevelError != null) throw updatePackLevelError!;
  }

  @override
  Future<void> updateRankProbabilities({
    required int level,
    required String hero,
    required String demigod,
    required String minorGod,
    required String majorGod,
  }) async {
    calls.add('updateRankProbabilities($level)');
    if (updateRankProbabilitiesError != null) throw updateRankProbabilitiesError!;
  }

  @override
  Future<void> updateRarityProbabilities({
    required int level,
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    calls.add('updateRarityProbabilities($level)');
    if (updateRarityProbabilitiesError != null) throw updateRarityProbabilitiesError!;
  }

  @override
  Future<void> updateRarityBonus({
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    calls.add('updateRarityBonus()');
    if (updateRarityBonusError != null) throw updateRarityBonusError!;
  }

  static GachaConfigEntity _defaultConfig() {
    return GachaConfigEntity(
      packLevels: [
        for (var level = 1; level <= 5; level++)
          GachaPackLevelConfig(
            level: level,
            price: level * 1000,
            cardsPerPack: 5,
            guaranteedMinRank: level >= 3 ? CardRank.demigod : null,
          ),
      ],
      rankProbabilities: [
        for (var level = 1; level <= 5; level++)
          GachaRankProbabilitiesConfig(
            level: level,
            hero: '0.5',
            demigod: '0.3',
            minorGod: '0.15',
            majorGod: '0.05',
          ),
      ],
      rarityProbabilities: [
        for (var level = 1; level <= 5; level++)
          GachaRarityProbabilitiesConfig(
            level: level,
            common: '0.7',
            rare: '0.2',
            epic: '0.08',
            legendary: '0.02',
          ),
      ],
      rarityBonus: GachaRarityBonusConfig(
        common: '0.00',
        rare: '0.10',
        epic: '0.20',
        legendary: '0.35',
      ),
    );
  }
}
