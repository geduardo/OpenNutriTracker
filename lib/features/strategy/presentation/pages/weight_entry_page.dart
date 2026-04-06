import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';

class WeightEntryPage extends StatefulWidget {
  const WeightEntryPage({super.key});

  @override
  State<WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<WeightEntryPage> {
  final _weightController = TextEditingController();
  List<WeightEntryEntity> _entries = [];
  double? _trendWeight;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = locator<WeightEntryRepository>();
    final entries = await repo.getAllEntries();
    final trend = TrendWeightService.getLatestTrendWeight(entries);

    if (mounted) {
      setState(() {
        _entries = entries;
        _trendWeight = trend;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight History')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWeight,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Trend weight summary
                if (_trendWeight != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        Text('Trend Weight',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          '${_trendWeight!.toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (_entries.isNotEmpty)
                          Text(
                            'Last weigh-in: ${_entries.last.weightKg.toStringAsFixed(1)} kg',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),

                // Weight history list
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('No weight entries yet'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            // Show newest first
                            final entry =
                                _entries[_entries.length - 1 - index];
                            final trendForDay =
                                TrendWeightService.getTrendWeightForDate(
                                    _entries, entry.day);
                            return ListTile(
                              leading: Icon(
                                entry.source ==
                                        WeightEntrySource.migratedProfileWeight
                                    ? Icons.sync
                                    : Icons.monitor_weight,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                  '${entry.weightKg.toStringAsFixed(1)} kg'),
                              subtitle: Text(_formatDate(entry.day)),
                              trailing: trendForDay != null
                                  ? Text(
                                      'trend: ${trendForDay.toStringAsFixed(1)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)
                                  : null,
                              onLongPress: () => _deleteEntry(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _addWeight() {
    _weightController.text = _entries.isNotEmpty
        ? _entries.last.weightKg.toStringAsFixed(1)
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final weight = double.tryParse(
                  _weightController.text.replaceAll(',', '.'));
              if (weight != null && weight > 0) {
                Navigator.pop(ctx);
                final repo = locator<WeightEntryRepository>();
                await repo.addEntry(WeightEntryEntity(
                  day: DateTime.now(),
                  weightKg: weight,
                  source: WeightEntrySource.manual,
                ));
                _loadData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(WeightEntryEntity entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
            'Delete ${entry.weightKg.toStringAsFixed(1)} kg on ${_formatDate(entry.day)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = locator<WeightEntryRepository>();
      await repo.deleteEntry(entry.day);
      _loadData();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
