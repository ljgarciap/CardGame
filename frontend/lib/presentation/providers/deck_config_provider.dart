import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/deck_config_repository_impl.dart';
import '../../domain/repositories/deck_config_repository.dart';

final deckConfigRepositoryProvider =
    Provider<DeckConfigRepository>((ref) => DeckConfigRepositoryImpl());
