import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_coins_repository_impl.dart';
import '../../domain/repositories/admin_coins_repository.dart';

final adminCoinsRepositoryProvider =
    Provider<AdminCoinsRepository>((ref) => AdminCoinsRepositoryImpl());
