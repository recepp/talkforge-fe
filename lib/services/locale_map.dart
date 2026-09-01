/// Shared language name to BCP-47 locale code mapping.
class AppLocaleMap {
  static const Map<String, String> _localeMap = {
    'Türkçe': 'tr-TR',
    'İngilizce': 'en-US',
    'Almanca': 'de-DE',
    'Fransızca': 'fr-FR',
    'İspanyolca': 'es-ES',
    'Arapça': 'ar-SA',
    'Rusça': 'ru-RU',
    // Fallbacks for 2-letter codes if present
    'tr': 'tr-TR',
    'en': 'en-US',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'ar': 'ar-SA',
    'ru': 'ru-RU',
  };

  /// Resolves the BCP-47 locale string for [langCodeOrName].
  /// Returns 'tr-TR' default if unmapped or empty.
  static String resolveLocale(String? langCodeOrName) {
    if (langCodeOrName == null || langCodeOrName.trim().isEmpty) {
      return 'tr-TR';
    }
    final trimmed = langCodeOrName.trim();
    return _localeMap[trimmed] ?? 'tr-TR';
  }
}
