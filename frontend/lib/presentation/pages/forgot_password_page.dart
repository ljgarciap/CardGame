import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _feedback;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _emailController.text.trim());
      // Mensaje genérico exista o no el email — así responde el backend también.
      setState(() =>
          _feedback = 'Si el email existe, te enviamos un link para restablecer tu contraseña.');
    } on ApiException catch (e) {
      setState(() => _feedback = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'RECUPERAR CONTRASEÑA',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Ingresá un email válido' : null,
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 16),
              Text(_feedback!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amber)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'ENVIAR LINK',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
              ),
              child: const Text('Ya tengo un token, restablecer ahora',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
