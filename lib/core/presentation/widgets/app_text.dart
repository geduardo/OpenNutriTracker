import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../generated/app_spanish.dart';
import '../../utils/app_language.dart';

// Additional screens inherited English copy rather than the legacy S API.
// This catalogue is used explicitly at UI boundaries, never on stored food data,
// API keys, JSON field names or prompts. Unknown text is left untouched.
final _templates = appSpanish.entries
    .where((entry) =>
        entry.key.contains(RegExp(r'\{\d+\}')) &&
        entry.key
            .replaceAll(RegExp(r'\{\d+\}'), '')
            .contains(RegExp(r'[A-Za-z]{3}')))
    .toList()
  ..sort((a, b) => b.key
      .replaceAll(RegExp(r'\{\d+\}'), '')
      .length
      .compareTo(a.key.replaceAll(RegExp(r'\{\d+\}'), '').length));
final _patterns = _templates.map((entry) {
  final parts = entry.key.split(RegExp(r'\{\d+\}'));
  return RegExp('^${parts.map(RegExp.escape).join('(.*?)')}\$', dotAll: true);
}).toList();

String tr(String source, {String? language}) {
  if ((language ?? Intl.getCurrentLocale()).split(RegExp('[-_]')).first != 'es') {
    return source;
  }
  final exact = appSpanish[source];
  if (exact != null) return exact;
  for (var i = 0; i < _patterns.length; i++) {
    final match = _patterns[i].firstMatch(source);
    if (match == null) continue;
    return _templates[i].value.replaceAllMapped(RegExp(r'\{(\d+)\}'),
        (placeholder) => match.group(int.parse(placeholder[1]!) + 1)!);
  }
  return source;
}

String? trOptional(String? source) => source == null ? null : tr(source);

/// A const-compatible localized label. It listens to Localizations so an open
/// screen updates immediately even when its parent widget was built with const.
class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final TextWidthBasis? textWidthBasis;
  final String? semanticsLabel;
  const AppText(this.data,
      {super.key,
      this.style,
      this.textAlign,
      this.overflow,
      this.maxLines,
      this.softWrap,
      this.textWidthBasis,
      this.semanticsLabel});
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Text(tr(data, language: language),
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
        textWidthBasis: textWidthBasis,
        semanticsLabel: semanticsLabel == null
            ? null
            : tr(semanticsLabel!, language: language));
  }
}

class LanguageSetting extends StatelessWidget {
  const LanguageSetting({super.key});
  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context);
    Localizations.localeOf(context);
    return ListenableBuilder(
        listenable: language,
        builder: (context, _) => ListTile(
              leading: const Icon(Icons.language),
              title: const AppText('Language'),
              subtitle: Text(switch (language.code) {
                'es' => 'Español',
                'en' => 'English',
                _ => tr('Follow phone'),
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) =>
                      SimpleDialog(title: const AppText('Language'), children: [
                        const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: AppText(
                                'Choose the language used throughout the app.')),
                        for (final option in <String?, String>{
                          null: 'Follow phone',
                          'es': 'Español',
                          'en': 'English'
                        }.entries)
                          SimpleDialogOption(
                              onPressed: () async {
                                try {
                                  await language.select(option.key);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } catch (_) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: AppText(
                                                'Could not save language. Please try again.')));
                                  }
                                }
                              },
                              child: Row(children: [
                                Icon(language.code == option.key
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked),
                                const SizedBox(width: 16),
                                AppText(option.value),
                              ])),
                      ])),
            ));
  }
}
