import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/domain/entities/gacha_config.dart';
import 'package:card_game/presentation/pages/marketplace_page.dart';
import 'package:card_game/presentation/pages/pack_opening_page.dart';
import 'package:card_game/presentation/providers/pack_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_pack_repository.dart';

Widget _appWith(FakePackRepository repository) {
  return ProviderScope(
    overrides: [packRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: MarketplacePage()),
  );
}

/// Los packs animan con un shimmer que se repite indefinidamente
/// (`.animate(onPlay: (c) => c.repeat(reverse: true))`), así que
/// `pumpAndSettle()` nunca "settlea" y tira timeout — se usa un pump acotado
/// en su lugar, suficiente para que el FutureBuilder resuelva y rebuildee.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('muestra los 5 niveles con precio y cartas reales del servidor', (tester) async {
    final repository = FakePackRepository(
      levelsToReturn: [
        GachaPackLevelConfig(level: 1, price: 1500, cardsPerPack: 5, guaranteedMinRank: null),
      ],
    );
    await tester.pumpWidget(_appWith(repository));
    await _pumpUntilLoaded(tester);

    expect(find.textContaining('1500'), findsOneWidget);
    expect(find.textContaining('5 CARDS'), findsOneWidget);
  });

  testWidgets('error al cargar los niveles muestra mensaje y botón reintentar', (tester) async {
    final repository = FakePackRepository()
      ..getPackLevelsError = ApiException(statusCode: 401, message: 'No autenticado');
    await tester.pumpWidget(_appWith(repository));
    await _pumpUntilLoaded(tester);

    expect(find.text('No autenticado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('tocar un pack navega a PackOpeningPage con el nivel correcto', (tester) async {
    final repository = FakePackRepository(
      levelsToReturn: [
        GachaPackLevelConfig(level: 3, price: 3000, cardsPerPack: 5, guaranteedMinRank: null),
      ],
    );
    await tester.pumpWidget(_appWith(repository));
    await _pumpUntilLoaded(tester);

    await tester.tap(find.byType(GestureDetector));
    await _pumpUntilLoaded(tester);

    final page = tester.widget<PackOpeningPage>(find.byType(PackOpeningPage));
    expect(page.level, 3);
  });
}
