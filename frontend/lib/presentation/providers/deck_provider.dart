import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/deck_repository_impl.dart';
import '../../domain/repositories/deck_repository.dart';

final deckRepositoryProvider = Provider<DeckRepository>((ref) => DeckRepositoryImpl());
