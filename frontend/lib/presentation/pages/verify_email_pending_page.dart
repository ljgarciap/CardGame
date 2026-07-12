import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import 'login_page.dart';

class VerifyEmailPendingPage extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailPendingPage({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailPendingPage> createState() =>
      _VerifyEmailPendingPageState();
}

class _VerifyEmailPendingPageState extends ConsumerState<VerifyEmailPendingPage> {
  bool _isSending = false;
  String? _feedback;

  Future<void> _resend() async {
    setState(() {
      _isSending = true;
      _feedback = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendVerification(email: widget.email);
      setState(() => _feedback = 'Te reenviamos el link de verificación.');
    } on ApiException catch (e) {
      setState(() => _feedback = e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'VERIFICÁ TU EMAIL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_unread_outlined,
              color: Colors.white.withOpacity(0.7), size: 72),
          const SizedBox(height: 20),
          Text(
            'Te enviamos un link de verificación a ${widget.email}. '
            'Hacé click en el link para poder iniciar sesión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            Text(_feedback!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber)),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'REENVIAR LINK',
            isLoading: _isSending,
            onPressed: _resend,
          ),
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
