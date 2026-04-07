import 'package:flutter/material.dart';

class MealGroupNameData {
  final String baseName;
  final double multiplier;

  const MealGroupNameData({
    required this.baseName,
    required this.multiplier,
  });
}

String formatMealMultiplier(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

MealGroupNameData parseMealGroupName(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return const MealGroupNameData(baseName: 'Meal', multiplier: 1);
  }

  final match = RegExp(r'^(.*)\s+\(([\d.,]+)x\)$').firstMatch(raw);
  if (match == null) {
    return MealGroupNameData(baseName: raw, multiplier: 1);
  }

  final parsedMultiplier =
      double.tryParse(match.group(2)!.replaceAll(',', '.')) ?? 1;
  final baseName = match.group(1)!.trim();
  return MealGroupNameData(
    baseName: baseName.isEmpty ? raw : baseName,
    multiplier: parsedMultiplier > 0 ? parsedMultiplier : 1,
  );
}

String buildMealGroupName(String baseName, double multiplier) {
  final trimmedName = baseName.trim();
  if ((multiplier - 1).abs() < 0.001) {
    return trimmedName;
  }

  return '$trimmedName (${formatMealMultiplier(multiplier)}x)';
}

Future<double?> showMealMultiplierDialog(
  BuildContext context, {
  required String mealName,
  required double totalKcal,
  String confirmLabel = 'Log meal',
  double initialMultiplier = 1,
}) async {
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => _MealMultiplierDialog(
      mealName: mealName,
      totalKcal: totalKcal,
      confirmLabel: confirmLabel,
      initialMultiplier: initialMultiplier,
    ),
  );
}

class _MealMultiplierDialog extends StatefulWidget {
  final String mealName;
  final double totalKcal;
  final String confirmLabel;
  final double initialMultiplier;

  const _MealMultiplierDialog({
    required this.mealName,
    required this.totalKcal,
    required this.confirmLabel,
    required this.initialMultiplier,
  });

  @override
  State<_MealMultiplierDialog> createState() => _MealMultiplierDialogState();
}

class _MealMultiplierDialogState extends State<_MealMultiplierDialog> {
  static const _options = <double>[0.5, 1, 1.5, 2];

  late final TextEditingController _controller;
  late double _selectedMultiplier;

  @override
  void initState() {
    super.initState();
    _selectedMultiplier = widget.initialMultiplier;
    _controller = TextEditingController(
      text: formatMealMultiplier(widget.initialMultiplier),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaledKcal =
        _selectedMultiplier > 0 ? widget.totalKcal * _selectedMultiplier : 0.0;

    return AlertDialog(
      title: const Text('Meal portion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much of "${widget.mealName}" do you want to log?'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options
                .map(
                  (value) => ChoiceChip(
                    label: Text('${formatMealMultiplier(value)}x'),
                    selected: (_selectedMultiplier - value).abs() < 0.001,
                    onSelected: (_) => _syncMultiplier(value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Custom multiplier',
              suffixText: 'x',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              setState(() {
                _selectedMultiplier = parsed ?? 0;
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            _selectedMultiplier > 0
                ? '${scaledKcal.toInt()} kcal total'
                : 'Enter a value greater than 0',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedMultiplier > 0
              ? () => Navigator.pop(context, _selectedMultiplier)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  void _syncMultiplier(double value) {
    setState(() {
      _selectedMultiplier = value;
      _controller.text = formatMealMultiplier(value);
    });
  }
}
