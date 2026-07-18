import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'login_page.dart';

/// Puede recibir [email] (viene del flujo de registro, habilita "reenviar
/// link") y/o [token] (viene del deep link `cardgame://verify-email?token=...`,
/// ver `main.dart`/`core/deep_link.dart` — precarga el campo y auto-verifica).
/// El campo de token queda editable igual, como fallback manual: es la única
/// forma de completar este flujo probando en web (`flutter run -d chrome`),
/// donde un custom URL scheme no dispara nada al abrir el link del correo.
class VerifyEmailPendingPage extends ConsumerStatefulWidget {
  final String? email;
  final String? token;

  const VerifyEmailPendingPage({super.key, this.email, this.token});

  @override
  ConsumerState<VerifyEmailPendingPage> createState() =>
      _VerifyEmailPendingPageState();
}

class _VerifyEmailPendingPageState extends ConsumerState<VerifyEmailPendingPage> {
  late final TextEditingController _tokenController;

  bool _isSending = false;
  String? _resendFeedback;

  bool _isVerifying = false;
  String? _verifyError;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.token ?? '');
    if (widget.token != null && widget.token!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _isSending = true;
      _resendFeedback = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendVerification(email: widget.email!);
      setState(() => _resendFeedback = 'Te reenviamos el link de verificación.');
    } on ApiException catch (e) {
      setState(() => _resendFeedback = e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmail(token: token);
      setState(() => _verified = true);
    } on ApiException catch (e) {
      setState(() => _verifyError = e.message);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return AuthScaffold(
        title: 'EMAIL VERIFICADO',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 20),
            Text(
              'Tu cuenta quedó verificada. Ya podés iniciar sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'IR A INICIAR SESIÓN',
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'VERIFICÁ TU EMAIL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_unread_outlined,
              color: Colors.white.withOpacity(0.7), size: 72),
          const SizedBox(height: 20),
          Text(
            widget.email != null
                ? 'Te enviamos un link de verificación a ${widget.email}. '
                    'Pegá el token del correo abajo o hacé click en el link.'
                : 'Pegá el token de verificación que recibiste por correo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            label: 'Token (del correo)',
            controller: _tokenController,
          ),
          if (_verifyError != null) ...[
            const SizedBox(height: 12),
            Text(_verifyError!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'VERIFICAR',
            isLoading: _isVerifying,
            onPressed: _verify,
          ),
          if (widget.email != null) ...[
            if (_resendFeedback != null) ...[
              const SizedBox(height: 16),
              Text(_resendFeedback!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amber)),
            ],
            const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'REENVIAR LINK',
              isLoading: _isSending,
              onPressed: _resend,
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: const Text('Ya verifiqué, ir a iniciar sesión',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
