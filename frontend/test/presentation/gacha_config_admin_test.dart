import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/presentation/pages/gacha_config_admin_page.dart';
import 'package:card_game/presentation/providers/gacha_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_gacha_config_repository.dart';

Widget _appWith(FakeGachaConfigRepository repository) {
  return ProviderScope(
    overrides: [gachaConfigRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: GachaConfigAdminPage()),
  );
}

void main() {
  testWidgets('muestra los 5 niveles y la sección de bono tras cargar', (tester) async {
    await tester.pumpWidget(_appWith(FakeGachaConfigRepository()));
    await tester.pumpAndSettle();

    expect(find.text('NIVEL 1'), findsOneWidget);
    expect(find.text('NIVEL 5'), findsOneWidget);
    expect(find.text('BONO DE RAREZA (global, no por nivel)'), findsOneWidget);
  });

  testWidgets('error al cargar config muestra mensaje y botón reintentar', (tester) async {
    final repo = FakeGachaConfigRepository()
      ..getConfigError =
          ApiException(statusCode: 403, message: 'Requiere permisos de superadmin');
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    expect(find.text('Requiere permisos de superadmin'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('guardar nivel 1 llama a los 3 PUT en orden y muestra éxito', (tester) async {
    final repo = FakeGachaConfigRepository();
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NIVEL 1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('GUARDAR NIVEL 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDAR NIVEL 1'));
    await tester.pumpAndSettle();

    expect(repo.calls, [
      'updatePackLevel(1)',
      'updateRankProbabilities(1)',
      'updateRarityProbabilities(1)',
    ]);
    expect(find.text('Nivel 1 guardado.'), findsOneWidget);
  });

  testWidgets('error 400 al guardar nivel muestra el mensaje del servidor', (tester) async {
    final repo = FakeGachaConfigRepository()
      ..updatePackLevelError = ApiException(statusCode: 400, message: 'price debe ser positivo');
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NIVEL 1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('GUARDAR NIVEL 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDAR NIVEL 1'));
    await tester.pumpAndSettle();

    expect(find.text('price debe ser positivo'), findsOneWidget);
  });

  testWidgets('guardar bono de rareza llama al repositorio y muestra éxito', (tester) async {
    final repo = FakeGachaConfigRepository();
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('GUARDAR BONO DE RAREZA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDAR BONO DE RAREZA'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['updateRarityBonus()']);
    expect(find.text('Bono de rareza guardado.'), findsOneWidget);
  });
}
