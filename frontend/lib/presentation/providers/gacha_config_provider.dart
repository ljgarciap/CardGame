import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/gacha_config_repository_impl.dart';
import '../../domain/repositories/gacha_config_repository.dart';

final gachaConfigRepositoryProvider =
    Provider<GachaConfigRepository>((ref) => GachaConfigRepositoryImpl());
