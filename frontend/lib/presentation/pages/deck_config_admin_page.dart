import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/deck_config.dart';
import '../providers/deck_config_provider.dart';
import '../widgets/async_future_view.dart';

/// Solo alcanzable si `user.isSuperadmin` — el backend igual devuelve 403
/// para cualquier otro caso, esta pantalla es solo el punto de entrada.
class DeckConfigAdminPage extends ConsumerStatefulWidget {
  const DeckConfigAdminPage({super.key});

  @override
  ConsumerState<DeckConfigAdminPage> createState() => _DeckConfigAdminPageState();
}

class _DeckConfigAdminPageState extends ConsumerState<DeckConfigAdminPage> {
  late Future<DeckConfigEntity> _configFuture;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _configFuture = ref.read(deckConfigRepositoryProvider).getConfig();
  }

  Future<void> _reload() async {
    setState(_loadConfig);
    await _configFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MAZOS CONFIG')),
      body: AsyncFutureView<DeckConfigEntity>(
        future: _configFuture,
        onRetry: _reload,
        errorFallbackMessage: 'No se pudo cargar la configuración.',
        builder: (context, config) => _MaxDecksSection(
          initialValue: config.maxDecksPerUser,
          onReloaded: _reload,
        ),
      ),
    );
  }
}

class _MaxDecksSection extends StatefulWidget {
  final int initialValue;
  final Future<void> Function() onReloaded;

  const _MaxDecksSection({required this.initialValue, required this.onReloaded});

  @override
  State<_MaxDecksSection> createState() => _MaxDecksSectionState();
}

class _MaxDecksSectionState extends State<_MaxDecksSection> {
  late final TextEditingController _controller;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(WidgetRef ref) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final value = int.parse(_controller.text);
      if (value <= 0) {
        throw const FormatException('debe ser positivo');
      }
      await ref.read(deckConfigRepositoryProvider).updateMaxDecksPerUser(value);
      await widget.onReloaded();
      if (!mounted) return;
      setState(() => _successMessage = 'Tope de mazos actualizado.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Ingresá un número entero positivo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TOPE DE MAZOS GUARDADOS POR USUARIO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Máximo de mazos'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_successMessage!, style: const TextStyle(color: Colors.greenAccent)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(ref),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('GUARDAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
