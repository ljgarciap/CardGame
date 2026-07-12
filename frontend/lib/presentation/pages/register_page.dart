import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar_presets.dart';
import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'login_page.dart';
import 'verify_email_pending_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String _selectedAvatar = avatarPresets.first;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
            avatarId: _selectedAvatar,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailPendingPage(email: _emailController.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'CREAR CUENTA',
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
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Username',
              controller: _usernameController,
              validator: (v) => (v == null || v.length < 3)
                  ? 'Mínimo 3 caracteres alfanuméricos'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Contraseña',
              controller: _passwordController,
              obscureText: true,
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Elegí un avatar',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 10),
            _AvatarPicker(
              selected: _selectedAvatar,
              onSelected: (id) => setState(() => _selectedAvatar = id),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'REGISTRARME',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text(
                '¿Ya tenés cuenta? Iniciá sesión',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _AvatarPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: avatarPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final id = avatarPresets[index];
          final isSelected = id == selected;
          return GestureDetector(
            onTap: () => onSelected(id),
            child: CircleAvatar(
              radius: 28,
              backgroundColor:
                  isSelected ? Colors.amber : Colors.white.withOpacity(0.08),
              child: Icon(
                Icons.person,
                color: isSelected ? Colors.black : Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }
}
