import 'package:card_game/core/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrae el token de un link de reset-password válido', () {
    final uri = Uri.parse('cardgame://reset-password?token=abc123');
    expect(extractResetPasswordToken(uri), 'abc123');
  });

  test('devuelve null para otro scheme', () {
    final uri = Uri.parse('https://reset-password?token=abc123');
    expect(extractResetPasswordToken(uri), isNull);
  });

  test('devuelve null para otro host', () {
    final uri = Uri.parse('cardgame://verify-email?token=abc123');
    expect(extractResetPasswordToken(uri), isNull);
  });

  test('devuelve null sin query param token', () {
    final uri = Uri.parse('cardgame://reset-password');
    expect(extractResetPasswordToken(uri), isNull);
  });

  test('devuelve null con token vacío', () {
    final uri = Uri.parse('cardgame://reset-password?token=');
    expect(extractResetPasswordToken(uri), isNull);
  });

  test('extrae el token de un link de verify-email válido', () {
    final uri = Uri.parse('cardgame://verify-email?token=xyz789');
    expect(extractVerifyEmailToken(uri), 'xyz789');
  });

  test('extractVerifyEmailToken devuelve null para otro host', () {
    final uri = Uri.parse('cardgame://reset-password?token=xyz789');
    expect(extractVerifyEmailToken(uri), isNull);
  });

  test('extractVerifyEmailToken devuelve null con token vacío', () {
    final uri = Uri.parse('cardgame://verify-email?token=');
    expect(extractVerifyEmailToken(uri), isNull);
  });
}
