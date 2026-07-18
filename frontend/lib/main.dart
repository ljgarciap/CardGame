import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/deep_link.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/main_menu_page.dart';
import 'presentation/pages/reset_password_page.dart';
import 'presentation/pages/verify_email_pending_page.dart';
import 'presentation/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: CardGameApp()));
}

class CardGameApp extends ConsumerStatefulWidget {
  const CardGameApp({super.key});

  @override
  ConsumerState<CardGameApp> createState() => _CardGameAppState();
}

class _CardGameAppState extends ConsumerState<CardGameApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Cold start: la app se abrió directamente desde el link (no estaba corriendo).
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleUri(initialUri);

    // App ya corriendo, llega un link nuevo (deep link mientras está abierta/en background).
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    final resetToken = extractResetPasswordToken(uri);
    if (resetToken != null) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ResetPasswordPage(token: resetToken)),
      );
      return;
    }

    final verifyToken = extractVerifyEmailToken(uri);
    if (verifyToken != null) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => VerifyEmailPendingPage(token: verifyToken)),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'MYTHOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Decide la pantalla inicial según si hay una sesión válida persistida.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authNotifierProvider).status;

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.amber)),
        );
      case AuthStatus.authenticated:
        return const MainMenuPage();
      case AuthStatus.unauthenticated:
        return const LoginPage();
    }
  }
}
