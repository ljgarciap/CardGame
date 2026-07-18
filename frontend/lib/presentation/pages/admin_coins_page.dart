import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/coin_grant.dart';
import '../providers/admin_coins_provider.dart';
import '../widgets/async_future_view.dart';

/// Solo alcanzable si `user.isSuperadmin` — el backend igual devuelve 403
/// para cualquier otro caso, esta pantalla es solo el punto de entrada.
class AdminCoinsPage extends ConsumerStatefulWidget {
  const AdminCoinsPage({super.key});

  @override
  ConsumerState<AdminCoinsPage> createState() => _AdminCoinsPageState();
}

class _AdminCoinsPageState extends ConsumerState<AdminCoinsPage> {
  late Future<List<CoinGrantEntity>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = ref.read(adminCoinsRepositoryProvider).getHistory();
  }

  Future<void> _reloadHistory() async {
    setState(_loadHistory);
    await _historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTORGAR COINS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GrantSection(onGranted: _reloadHistory),
          const SizedBox(height: 16),
          _BroadcastSection(onGranted: _reloadHistory),
          const SizedBox(height: 16),
          const Text('HISTORIAL', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: AsyncFutureView<List<CoinGrantEntity>>(
              future: _historyFuture,
              onRetry: _reloadHistory,
              errorFallbackMessage: 'No se pudo cargar el historial.',
              builder: (context, grants) => _HistoryList(grants: grants),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<CoinGrantEntity> grants;

  const _HistoryList({required this.grants});

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) {
      return const Center(child: Text('Todavía no se otorgaron coins.'));
    }
    return ListView.separated(
      itemCount: grants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final grant = grants[index];
        final target = grant.isBroadcast
            ? 'Comunidad (${grant.recipientCount} usuarios)'
            : grant.targetUsername!;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.monetization_on_outlined, color: Colors.amber),
          title: Text('+${grant.amount} → $target'),
          subtitle: Text(
            [
              'por ${grant.grantedByUsername}',
              if (grant.reason != null && grant.reason!.isNotEmpty) grant.reason!,
            ].join(' · '),
          ),
          trailing: Text(
            '${grant.createdAt.toLocal()}'.split('.').first,
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }
}

class _GrantSection extends StatefulWidget {
  final Future<void> Function() onGranted;

  const _GrantSection({required this.onGranted});

  @override
  State<_GrantSection> createState() => _GrantSectionState();
}

class _GrantSectionState extends State<_GrantSection> {
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(WidgetRef ref) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final amount = int.parse(_amountController.text);
      if (amount <= 0) throw const FormatException('debe ser positivo');

      final newBalance = await ref.read(adminCoinsRepositoryProvider).grant(
            userIdentifier: _identifierController.text.trim(),
            amount: amount,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      await widget.onGranted();
      if (!mounted) return;
      setState(() =>
          _successMessage = 'Otorgado. Nuevo saldo: $newBalance coins.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Ingresá un monto entero positivo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('OTORGAR A UN USUARIO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _identifierController,
                decoration:
                    const InputDecoration(labelText: 'Email o username del jugador'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto (coins)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
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
                onPressed: _isSaving ? null : () => _submit(ref),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('OTORGAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastSection extends StatefulWidget {
  final Future<void> Function() onGranted;

  const _BroadcastSection({required this.onGranted});

  @override
  State<_BroadcastSection> createState() => _BroadcastSectionState();
}

class _BroadcastSectionState extends State<_BroadcastSection> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<bool> _confirm(BuildContext context, int amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar evento'),
        content: Text(
          'Esto otorga $amount coins a TODOS los usuarios registrados, '
          'de forma inmediata e irreversible. ¿Confirmás?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final int amount;
    try {
      amount = int.parse(_amountController.text);
      if (amount <= 0) throw const FormatException('debe ser positivo');
    } catch (_) {
      setState(() => _errorMessage = 'Ingresá un monto entero positivo.');
      return;
    }

    if (!await _confirm(context, amount)) return;

    setState(() => _isSaving = true);
    try {
      final recipientCount = await ref.read(adminCoinsRepositoryProvider).broadcast(
            amount: amount,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      await widget.onGranted();
      if (!mounted) return;
      setState(() =>
          _successMessage = 'Otorgado a $recipientCount usuarios.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('EVENTO PARA TODA LA COMUNIDAD',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto (coins) por usuario'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
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
              OutlinedButton(
                onPressed: _isSaving ? null : () => _submit(context, ref),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('LANZAR EVENTO A TODA LA COMUNIDAD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
