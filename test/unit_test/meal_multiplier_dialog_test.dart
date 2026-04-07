import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_multiplier_dialog.dart';

void main() {
  group('formatMealMultiplier', () {
    test('drops trailing decimals for whole numbers', () {
      expect(formatMealMultiplier(1), '1');
      expect(formatMealMultiplier(2), '2');
    });

    test('keeps meaningful decimal precision', () {
      expect(formatMealMultiplier(0.5), '0.5');
      expect(formatMealMultiplier(1.5), '1.5');
      expect(formatMealMultiplier(1.25), '1.25');
    });
  });

  group('meal group names', () {
    test('builds names without suffix for 1x meals', () {
      expect(buildMealGroupName('Breakfast Plate', 1), 'Breakfast Plate');
    });

    test('builds names with suffix for scaled meals', () {
      expect(buildMealGroupName('Breakfast Plate', 0.5),
          'Breakfast Plate (0.5x)');
    });

    test('parses scaled meal names back into base name and multiplier', () {
      final parsed = parseMealGroupName('Breakfast Plate (1.5x)');

      expect(parsed.baseName, 'Breakfast Plate');
      expect(parsed.multiplier, 1.5);
    });
  });
}
