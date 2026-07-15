import '../../core/errors/api_exception.dart';
import '../../domain/entities/card.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/repositories/gacha_config_repository.dart';
import '../datasources/gacha_config_remote_datasource.dart';
import '../datasources/token_storage.dart';

class GachaConfigRepositoryImpl implements GachaConfigRepository {
  final GachaConfigRemoteDatasource _remote;
  final TokenStorage _tokenStorage;

  GachaConfigRepositoryImpl({
    GachaConfigRemoteDatasource? remote,
    TokenStorage? tokenStorage,
  })  : _remote = remote ?? GachaConfigRemoteDatasource(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'No autenticado');
    }
    return token;
  }

  @override
  Future<GachaConfigEntity> getConfig() async {
    final token = await _requireToken();
    final json = await _remote.getConfig(token: token);
    return GachaConfigEntity.fromJson(json);
  }

  @override
  Future<void> updatePackLevel({
    required int level,
    required int price,
    required CardRank? guaranteedMinRank,
  }) async {
    final token = await _requireToken();
    await _remote.updatePackLevel(
      token: token,
      level: level,
      price: price,
      guaranteedMinRank: guaranteedMinRank,
    );
  }

  @override
  Future<void> updateRankProbabilities({
    required int level,
    required String hero,
    required String demigod,
    required String minorGod,
    required String majorGod,
  }) async {
    final token = await _requireToken();
    await _remote.updateRankProbabilities(
      token: token,
      level: level,
      hero: hero,
      demigod: demigod,
      minorGod: minorGod,
      majorGod: majorGod,
    );
  }

  @override
  Future<void> updateRarityProbabilities({
    required int level,
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    final token = await _requireToken();
    await _remote.updateRarityProbabilities(
      token: token,
      level: level,
      common: common,
      rare: rare,
      epic: epic,
      legendary: legendary,
    );
  }

  @override
  Future<void> updateRarityBonus({
    required String common,
    required String rare,
    required String epic,
    required String legendary,
  }) async {
    final token = await _requireToken();
    await _remote.updateRarityBonus(
      token: token,
      common: common,
      rare: rare,
      epic: epic,
      legendary: legendary,
    );
  }
}
