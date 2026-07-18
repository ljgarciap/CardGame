import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const AuthScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E),
            Color(0xFF311B92),
            Color(0xFF000000),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sin título propio: Flutter agrega la flecha de volver sola cuando
        // Navigator.canPop() es true (ej. ForgotPassword, Profile,
        // ChangePassword — llegan con push) y no la agrega cuando es false
        // (ej. Login, o Register llegando por pushReplacement) — evita tener
        // que decidir a mano pantalla por pantalla.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MYTHOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
