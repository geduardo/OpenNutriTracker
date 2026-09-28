import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/generated/l10n.dart';

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
    final s = S.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDate);
    final isToday = DateUtils.isSameDay(selected, today);
    final canGoForward = !isToday;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: s.previousDayLabel,
            onPressed: () => _shiftDay(-1),
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
                      _relativeLabel(s, selected, today),
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
              child: Tooltip(
                message: s.jumpToTodayLabel,
                child: TextButton(
                  onPressed: () => onDateChanged(today),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(s.todayLabel),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: s.nextDayLabel,
            onPressed: canGoForward ? () => _shiftDay(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: s.pickDateLabel,
            onPressed: () => _pickDate(context),
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

  /// Compares calendar dates; `difference().inDays` is off by one across a
  /// daylight-saving change.
  static String _relativeLabel(S s, DateTime selected, DateTime today) {
    if (DateUtils.isSameDay(selected, today)) return s.todayLabel;
    if (DateUtils.isSameDay(selected, DateUtils.addDaysToDate(today, -1))) {
      return s.yesterdayLabel;
    }
    return DateFormat.EEEE().format(selected);
  }
}
