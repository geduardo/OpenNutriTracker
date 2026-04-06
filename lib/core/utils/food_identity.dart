import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

class FoodIdentity {
  static String normalizeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String lookupAlias(String rawKey) => 'lookup:${normalizeText(rawKey)}';

  static String? codeAlias(MealDBO meal) {
    final code = meal.code;
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    return 'code:${meal.source.name}:${normalizeText(code)}';
  }

  static String? nameAlias(MealDBO meal) {
    final name = meal.name;
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    return 'name:${normalizeText(name)}';
  }

  static List<String> candidateAliases(
    MealDBO meal, {
    List<String> lookupKeys = const [],
  }) {
    final aliases = <String>[
      for (final key in lookupKeys)
        if (key.trim().isNotEmpty) lookupAlias(key),
      if (codeAlias(meal) != null) codeAlias(meal)!,
      if (nameAlias(meal) != null) nameAlias(meal)!,
    ];
    return aliases.toSet().toList(growable: false);
  }
}
