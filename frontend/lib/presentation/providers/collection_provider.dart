import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository_impl.dart';
import '../../domain/repositories/collection_repository.dart';

final collectionRepositoryProvider =
    Provider<CollectionRepository>((ref) => CollectionRepositoryImpl());
