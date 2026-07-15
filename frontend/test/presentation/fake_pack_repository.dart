import 'package:card_game/domain/entities/gacha_config.dart';
import 'package:card_game/domain/entities/pack.dart';
import 'package:card_game/domain/repositories/pack_repository.dart';

class FakePackRepository implements PackRepository {
  List<GachaPackLevelConfig>? levelsToReturn;
  Object? getPackLevelsError;

  PackOpenResultEntity? openPackResult;
  Object? openPackError;

  final List<String> calls = [];

  FakePackRepository({this.levelsToReturn, this.openPackResult});

  @override
  Future<List<GachaPackLevelConfig>> getPackLevels() async {
    if (getPackLevelsError != null) throw getPackLevelsError!;
    return levelsToReturn ?? _defaultLevels();
  }

  @override
  Future<PackOpenResultEntity> openPack({required int level}) async {
    calls.add('openPack($level)');
    if (openPackError != null) throw openPackError!;
    return openPackResult ?? PackOpenResultEntity(cards: [], remainingCoins: 0);
  }

  static List<GachaPackLevelConfig> _defaultLevels() {
    return [
      for (var level = 1; level <= 5; level++)
        GachaPackLevelConfig(
          level: level,
          price: level * 1000,
          cardsPerPack: 5,
          guaranteedMinRank: null,
        ),
    ];
  }
}
