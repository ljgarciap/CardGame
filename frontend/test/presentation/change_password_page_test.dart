import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/presentation/pages/change_password_page.dart';
import 'package:card_game/presentation/providers/auth_provider.dart';
import 'package:card_game/presentation/widgets/auth_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

Widget _appWith(FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ChangePasswordPage()),
  );
}

void main() {
  testWidgets('cambio exitoso muestra pantalla de confirmación', (tester) async {
    await tester.pumpWidget(_appWith(FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña actual'), 'currentpass123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'), 'brandnewpass123');
    await tester.tap(find.widgetWithText(AuthPrimaryButton, 'CAMBIAR CONTRASEÑA'));
    await tester.pumpAndSettle();

    expect(find.text('Tu contraseña se actualizó correctamente.'), findsOneWidget);
  });

  testWidgets('contraseña actual incorrecta muestra el mensaje del servidor',
      (tester) async {
    final repository = FakeAuthRepository()
      ..changePasswordError =
          ApiException(statusCode: 400, message: 'Contraseña actual incorrecta');
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña actual'), 'wrongpass123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'), 'brandnewpass123');
    await tester.tap(find.widgetWithText(AuthPrimaryButton, 'CAMBIAR CONTRASEÑA'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña actual incorrecta'), findsOneWidget);
  });

  testWidgets('valida longitud mínima de la nueva contraseña sin llamar al repositorio',
      (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña actual'), 'currentpass123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), 'short');
    await tester.tap(find.widgetWithText(AuthPrimaryButton, 'CAMBIAR CONTRASEÑA'));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });
}
