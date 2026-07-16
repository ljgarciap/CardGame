import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/card.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/repositories/gacha_config_repository.dart';
import '../providers/gacha_config_provider.dart';
import '../widgets/async_future_view.dart';

/// Solo alcanzable si `user.isSuperadmin` — el backend igual devuelve 403
/// para cualquier otro caso, esta pantalla es solo el punto de entrada.
class GachaConfigAdminPage extends ConsumerStatefulWidget {
  const GachaConfigAdminPage({super.key});

  @override
  ConsumerState<GachaConfigAdminPage> createState() => _GachaConfigAdminPageState();
}

class _GachaConfigAdminPageState extends ConsumerState<GachaConfigAdminPage> {
  late Future<GachaConfigEntity> _configFuture;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _configFuture = ref.read(gachaConfigRepositoryProvider).getConfig();
  }

  Future<void> _reload() async {
    setState(_loadConfig);
    await _configFuture;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(gachaConfigRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GACHA CONFIG')),
      body: AsyncFutureView<GachaConfigEntity>(
        future: _configFuture,
        onRetry: _reload,
        errorFallbackMessage: 'No se pudo cargar la configuración.',
        builder: (context, config) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final level in config.packLevels)
                _LevelConfigSection(
                  key: ValueKey('level-${level.level}'),
                  level: level,
                  rankProbabilities: config.rankProbabilities
                      .firstWhere((r) => r.level == level.level),
                  rarityProbabilities: config.rarityProbabilities
                      .firstWhere((r) => r.level == level.level),
                  repository: repository,
                ),
              const SizedBox(height: 8),
              _RarityBonusSection(bonus: config.rarityBonus, repository: repository),
            ],
          );
        },
      ),
    );
  }
}

String _rankLabel(CardRank rank) {
  switch (rank) {
    case CardRank.hero:
      return 'Hero';
    case CardRank.demigod:
      return 'Demigod';
    case CardRank.minorGod:
      return 'Minor God';
    case CardRank.majorGod:
      return 'Major God';
  }
}

Color _sumColor(double sum) =>
    (sum - 1.0).abs() < 0.0001 ? Colors.greenAccent : Colors.orangeAccent;

class _LevelConfigSection extends StatefulWidget {
  final GachaPackLevelConfig level;
  final GachaRankProbabilitiesConfig rankProbabilities;
  final GachaRarityProbabilitiesConfig rarityProbabilities;
  final GachaConfigRepository repository;

  const _LevelConfigSection({
    super.key,
    required this.level,
    required this.rankProbabilities,
    required this.rarityProbabilities,
    required this.repository,
  });

  @override
  State<_LevelConfigSection> createState() => _LevelConfigSectionState();
}

class _LevelConfigSectionState extends State<_LevelConfigSection> {
  late final TextEditingController _priceController;
  late final TextEditingController _cardsPerPackController;
  CardRank? _guaranteedMinRank;

  late final TextEditingController _heroController;
  late final TextEditingController _demigodController;
  late final TextEditingController _minorGodController;
  late final TextEditingController _majorGodController;

  late final TextEditingController _commonController;
  late final TextEditingController _rareController;
  late final TextEditingController _epicController;
  late final TextEditingController _legendaryController;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  List<TextEditingController> get _rankControllers =>
      [_heroController, _demigodController, _minorGodController, _majorGodController];

  List<TextEditingController> get _rarityControllers =>
      [_commonController, _rareController, _epicController, _legendaryController];

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.level.price.toString());
    _cardsPerPackController = TextEditingController(text: widget.level.cardsPerPack.toString());
    _guaranteedMinRank = widget.level.guaranteedMinRank;

    _heroController = TextEditingController(text: widget.rankProbabilities.hero);
    _demigodController = TextEditingController(text: widget.rankProbabilities.demigod);
    _minorGodController = TextEditingController(text: widget.rankProbabilities.minorGod);
    _majorGodController = TextEditingController(text: widget.rankProbabilities.majorGod);

    _commonController = TextEditingController(text: widget.rarityProbabilities.common);
    _rareController = TextEditingController(text: widget.rarityProbabilities.rare);
    _epicController = TextEditingController(text: widget.rarityProbabilities.epic);
    _legendaryController = TextEditingController(text: widget.rarityProbabilities.legendary);

    for (final c in [..._rankControllers, ..._rarityControllers]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _cardsPerPackController.dispose();
    for (final c in [..._rankControllers, ..._rarityControllers]) {
      c.dispose();
    }
    super.dispose();
  }

  double _sumOf(List<TextEditingController> controllers) =>
      controllers.fold(0.0, (sum, c) => sum + (double.tryParse(c.text) ?? 0));

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await widget.repository.updatePackLevel(
        level: widget.level.level,
        price: int.parse(_priceController.text),
        cardsPerPack: int.parse(_cardsPerPackController.text),
        guaranteedMinRank: _guaranteedMinRank,
      );
      await widget.repository.updateRankProbabilities(
        level: widget.level.level,
        hero: _heroController.text,
        demigod: _demigodController.text,
        minorGod: _minorGodController.text,
        majorGod: _majorGodController.text,
      );
      await widget.repository.updateRarityProbabilities(
        level: widget.level.level,
        common: _commonController.text,
        rare: _rareController.text,
        epic: _epicController.text,
        legendary: _legendaryController.text,
      );
      if (!mounted) return;
      setState(() => _successMessage = 'Nivel ${widget.level.level} guardado.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      // price no numérico, etc. — sin esto el error queda silencioso.
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo guardar. Revisá los valores.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankSum = _sumOf(_rankControllers);
    final raritySum = _sumOf(_rarityControllers);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text('NIVEL ${widget.level.level}'),
        subtitle: Text('${widget.level.price} coins'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio (coins)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardsPerPackController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cartas por sobre'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CardRank?>(
                  value: _guaranteedMinRank,
                  decoration: const InputDecoration(labelText: 'Garantía mínima de rango'),
                  items: [
                    const DropdownMenuItem<CardRank?>(value: null, child: Text('Sin garantía')),
                    ...CardRank.values.map(
                      (r) => DropdownMenuItem<CardRank?>(value: r, child: Text(_rankLabel(r))),
                    ),
                  ],
                  onChanged: (v) => setState(() => _guaranteedMinRank = v),
                ),
                const SizedBox(height: 20),
                Text(
                  'Probabilidades de rango  (suma: ${rankSum.toStringAsFixed(4)})',
                  style: TextStyle(color: _sumColor(rankSum), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _probabilityField('Hero', _heroController),
                _probabilityField('Demigod', _demigodController),
                _probabilityField('Minor God', _minorGodController),
                _probabilityField('Major God', _majorGodController),
                const SizedBox(height: 20),
                Text(
                  'Probabilidades de rareza  (suma: ${raritySum.toStringAsFixed(4)})',
                  style: TextStyle(color: _sumColor(raritySum), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _probabilityField('Common', _commonController),
                _probabilityField('Rare', _rareController),
                _probabilityField('Epic', _epicController),
                _probabilityField('Legendary', _legendaryController),
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
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('GUARDAR NIVEL ${widget.level.level}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _probabilityField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _RarityBonusSection extends StatefulWidget {
  final GachaRarityBonusConfig bonus;
  final GachaConfigRepository repository;

  const _RarityBonusSection({required this.bonus, required this.repository});

  @override
  State<_RarityBonusSection> createState() => _RarityBonusSectionState();
}

class _RarityBonusSectionState extends State<_RarityBonusSection> {
  late final TextEditingController _commonController;
  late final TextEditingController _rareController;
  late final TextEditingController _epicController;
  late final TextEditingController _legendaryController;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _commonController = TextEditingController(text: widget.bonus.common);
    _rareController = TextEditingController(text: widget.bonus.rare);
    _epicController = TextEditingController(text: widget.bonus.epic);
    _legendaryController = TextEditingController(text: widget.bonus.legendary);
  }

  @override
  void dispose() {
    _commonController.dispose();
    _rareController.dispose();
    _epicController.dispose();
    _legendaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await widget.repository.updateRarityBonus(
        common: _commonController.text,
        rare: _rareController.text,
        epic: _epicController.text,
        legendary: _legendaryController.text,
      );
      if (!mounted) return;
      setState(() => _successMessage = 'Bono de rareza guardado.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo guardar. Revisá los valores.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BONO DE RAREZA (global, no por nivel)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _bonusField('Common', _commonController),
            _bonusField('Rare', _rareController),
            _bonusField('Epic', _epicController),
            _bonusField('Legendary', _legendaryController),
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
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('GUARDAR BONO DE RAREZA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bonusField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
