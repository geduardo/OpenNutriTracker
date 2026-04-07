import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact header that lets the user navigate days on the diary page.
///
/// Layout: `<` prev | date label (tappable, opens picker) | `>` next | calendar icon
/// A small "Today" jump button appears when the selected date is not today.
class DayNavigationBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DayNavigationBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDate);
    final isToday = DateUtils.isSameDay(selected, today);
    final canGoForward = !isToday;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Semantics(
            label: 'Previous day',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftDay(-1),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.MMMEd().format(selected),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _relativeLabel(selected, today),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                label: 'Jump to today',
                button: true,
                child: TextButton(
                  onPressed: () => onDateChanged(today),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Today'),
                ),
              ),
            ),
          Semantics(
            label: 'Next day',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoForward ? () => _shiftDay(1) : null,
            ),
          ),
          Semantics(
            label: 'Pick a date',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () => _pickDate(context),
            ),
          ),
        ],
      ),
    );
  }

  void _shiftDay(int delta) {
    final next = DateUtils.addDaysToDate(selectedDate, delta);
    onDateChanged(DateUtils.dateOnly(next));
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );
    if (picked != null) {
      onDateChanged(DateUtils.dateOnly(picked));
    }
  }

  static String _relativeLabel(DateTime selected, DateTime today) {
    final diffDays = selected.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == -1) return 'Yesterday';
    if (diffDays == 1) return 'Tomorrow';
    return DateFormat.EEEE().format(selected);
  }
}
