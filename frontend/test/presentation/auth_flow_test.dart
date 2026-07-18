import 'package:card_game/core/errors/api_exception.dart';
import 'package:card_game/domain/entities/user_account.dart';
import 'package:card_game/main.dart';
import 'package:card_game/presentation/pages/login_page.dart';
import 'package:card_game/presentation/pages/main_menu_page.dart';
import 'package:card_game/presentation/pages/register_page.dart';
import 'package:card_game/presentation/pages/verify_email_pending_page.dart';
import 'package:card_game/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

Widget _appWith(FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const CardGameApp(),
  );
}

void main() {
  testWidgets('AuthGate muestra LoginPage cuando no hay sesión', (tester) async {
    await tester.pumpWidget(_appWith(FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('AuthGate muestra MainMenuPage cuando ya hay sesión válida',
      (tester) async {
    final repository = FakeAuthRepository(
      storedToken: 'existing-token',
      profile: UserAccountEntity(
        id: 'user-1',
        email: 'a@a.com',
        username: 'player_one',
        avatarId: 'avatar_1',
        coins: 0,
        emailVerified: true,
        isSuperadmin: false,
      ),
    );
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    expect(find.byType(MainMenuPage), findsOneWidget);
  });

  testWidgets('Login exitoso navega a MainMenuPage', (tester) async {
    await tester.pumpWidget(_appWith(FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@a.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'supersecret123');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();

    expect(find.byType(MainMenuPage), findsOneWidget);
  });

  testWidgets('Login fallido muestra el mensaje de error sin navegar',
      (tester) async {
    final repository = FakeAuthRepository()
      ..loginError = ApiException(statusCode: 401, message: 'Email o contraseña incorrectos');
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@a.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'wrongpassword');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();

    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('Registro exitoso navega a VerifyEmailPendingPage', (tester) async {
    await tester.pumpWidget(_appWith(FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿No tenés cuenta? Registrate'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'nuevo@a.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'nuevo_user');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'supersecret123');
    await tester.tap(find.text('REGISTRARME'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPendingPage), findsOneWidget);
    expect(find.textContaining('nuevo@a.com'), findsOneWidget);
  });

  Future<void> registerAndReachVerifyPage(WidgetTester tester) async {
    await tester.tap(find.text('¿No tenés cuenta? Registrate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'nuevo@a.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'nuevo_user');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'supersecret123');
    await tester.tap(find.text('REGISTRARME'));
    await tester.pumpAndSettle();
  }

  testWidgets('Verificar con token manual muestra pantalla de éxito',
      (tester) async {
    await tester.pumpWidget(_appWith(FakeAuthRepository()));
    await tester.pumpAndSettle();
    await registerAndReachVerifyPage(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Token (del correo)'), 'abc123');
    await tester.tap(find.text('VERIFICAR'));
    await tester.pumpAndSettle();

    expect(find.text('Tu cuenta quedó verificada. Ya podés iniciar sesión.'),
        findsOneWidget);
  });

  testWidgets('Verificar con token inválido muestra el mensaje del servidor',
      (tester) async {
    final repository = FakeAuthRepository()
      ..verifyEmailError =
          ApiException(statusCode: 400, message: 'Token inválido o expirado');
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();
    await registerAndReachVerifyPage(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Token (del correo)'), 'bad-token');
    await tester.tap(find.text('VERIFICAR'));
    await tester.pumpAndSettle();

    expect(find.text('Token inválido o expirado'), findsOneWidget);
  });
}
