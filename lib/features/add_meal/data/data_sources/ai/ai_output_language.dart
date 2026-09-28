import 'package:intl/intl.dart';

/// Changes only human-readable output. The nutrition protocol stays stable.
String aiOutputLanguageInstruction() {
  final language = Intl.getCurrentLocale().split(RegExp('[-_]')).first == 'es'
      ? 'Spanish'
      : 'English';
  return 'Write food names, meal_name, clarification questions and suggested '
      'answers in $language. Preserve brand names. Keep every JSON key, enum '
      'value (including confidence and source), unit and numeric format exactly '
      'as specified by the schema. Do not translate protocol values.';
}
