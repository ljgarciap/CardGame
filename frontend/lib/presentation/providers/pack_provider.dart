import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/pack_repository_impl.dart';
import '../../domain/repositories/pack_repository.dart';

final packRepositoryProvider = Provider<PackRepository>((ref) => PackRepositoryImpl());
