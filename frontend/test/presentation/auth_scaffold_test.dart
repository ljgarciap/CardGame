import 'package:card_game/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el wordmark MYTHOS junto con el título de la pantalla',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AuthScaffold(title: 'INICIAR SESIÓN', child: SizedBox()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('MYTHOS'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });

  testWidgets('sin botón de volver cuando es la pantalla raíz (nada que popear)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AuthScaffold(title: 'INICIAR SESIÓN', child: SizedBox()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('con botón de volver cuando se llega con push', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const AuthScaffold(title: 'OLVIDÉ MI CONTRASEÑA', child: SizedBox()),
            ),
          ),
          child: const Text('ir'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ir'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('OLVIDÉ MI CONTRASEÑA'), findsNothing);
    expect(find.text('ir'), findsOneWidget);
  });
}
