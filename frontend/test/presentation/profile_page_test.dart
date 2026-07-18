import 'package:card_game/domain/entities/user_account.dart';
import 'package:card_game/presentation/pages/profile_page.dart';
import 'package:card_game/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

UserAccountEntity _user({required bool isSuperadmin}) => UserAccountEntity(
      id: 'user-1',
      email: 'a@a.com',
      username: 'player_one',
      avatarId: 'avatar_1',
      coins: 0,
      emailVerified: true,
      isSuperadmin: isSuperadmin,
    );

Widget _appWith(FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ProfilePage()),
  );
}

void main() {
  testWidgets('usuario regular no ve navegación admin ni el toggle de rol',
      (tester) async {
    final repository = FakeAuthRepository(
      storedToken: 'token',
      profile: _user(isSuperadmin: false),
    );
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    expect(find.text('CAMBIAR CONTRASEÑA'), findsOneWidget);
    expect(find.text('VER COMO JUGADOR'), findsNothing);
    expect(find.text('ADMIN: OTORGAR COINS'), findsNothing);
  });

  testWidgets('superadmin ve la navegación admin y puede pasar a modo jugador',
      (tester) async {
    final repository = FakeAuthRepository(
      storedToken: 'token',
      profile: _user(isSuperadmin: true),
    );
    await tester.pumpWidget(_appWith(repository));
    await tester.pumpAndSettle();

    expect(find.text('VER COMO JUGADOR'), findsOneWidget);
    expect(find.text('ADMIN: CONFIG DE GACHA'), findsOneWidget);
    expect(find.text('ADMIN: CONFIG DE MAZOS'), findsOneWidget);
    expect(find.text('ADMIN: OTORGAR COINS'), findsOneWidget);

    await tester.tap(find.text('VER COMO JUGADOR'));
    await tester.pumpAndSettle();

    expect(find.text('ADMIN: CONFIG DE GACHA'), findsNothing);
    expect(find.text('ADMIN: OTORGAR COINS'), findsNothing);
    expect(find.text('VOLVER A MODO ADMIN'), findsOneWidget);

    await tester.tap(find.text('VOLVER A MODO ADMIN'));
    await tester.pumpAndSettle();

    expect(find.text('ADMIN: OTORGAR COINS'), findsOneWidget);
  });
}
