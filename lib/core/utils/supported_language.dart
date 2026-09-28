enum SupportedLanguage {
  en,
  es,
  de;

  factory SupportedLanguage.fromCode(String localeCode) {
    final languageCode = localeCode.split(RegExp('[-_]')).first;
    switch (languageCode) {
      case 'es':
        return SupportedLanguage.es;
      case 'en':
        return SupportedLanguage.en;
      case 'de':
        return SupportedLanguage.de;
      default:
        return SupportedLanguage.en;
    }
  }
}
