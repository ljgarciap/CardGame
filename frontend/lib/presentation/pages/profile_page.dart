import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/avatar_presets.dart';
import '../../core/errors/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'deck_config_admin_page.dart';
import 'gacha_config_admin_page.dart';
import 'login_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _usernameController;
  String? _selectedAvatar;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _selectedAvatar = user?.avatarId;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            username: _usernameController.text.trim(),
            avatarId: _selectedAvatar,
          );
      setState(() => _successMessage = 'Perfil actualizado correctamente.');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return AuthScaffold(
      title: 'MI PERFIL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.coins, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text('${user.coins}', style: const TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
          ],
          AuthTextField(
            label: 'Username',
            controller: _usernameController,
            validator: (v) => (v == null || v.length < 3)
                ? 'Mínimo 3 caracteres alfanuméricos'
                : null,
          ),
          const SizedBox(height: 16),
          Text('Avatar', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avatarPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final id = avatarPresets[index];
                final isSelected = id == _selectedAvatar;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = id),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        isSelected ? Colors.amber : Colors.white.withOpacity(0.08),
                    child: Icon(Icons.person,
                        color: isSelected ? Colors.black : Colors.white54),
                  ),
                );
              },
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            Text(_successMessage!, style: const TextStyle(color: Colors.greenAccent)),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'GUARDAR',
            isLoading: _isSaving,
            onPressed: _save,
          ),
          if (user?.isSuperadmin ?? false) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GachaConfigAdminPage()),
                );
              },
              icon: const FaIcon(FontAwesomeIcons.gears, size: 16),
              label: const Text('ADMIN: CONFIG DE GACHA'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeckConfigAdminPage()),
                );
              },
              icon: const FaIcon(FontAwesomeIcons.layerGroup, size: 16),
              label: const Text('ADMIN: CONFIG DE MAZOS'),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: _logout,
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
