import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

/// Cambio de contraseña estando logueado (requiere la actual) — distinto
/// del flujo de "olvidé mi contraseña" (`forgot_password_page.dart` +
/// `reset_password_page.dart`), que no requiere sesión y usa un token por
/// email en su lugar.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      setState(() => _success = true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return AuthScaffold(
        title: 'CONTRASEÑA ACTUALIZADA',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 20),
            Text(
              'Tu contraseña se actualizó correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'VOLVER',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'CAMBIAR CONTRASEÑA',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              label: 'Contraseña actual',
              controller: _currentPasswordController,
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Nueva contraseña',
              controller: _newPasswordController,
              obscureText: true,
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'CAMBIAR CONTRASEÑA',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
