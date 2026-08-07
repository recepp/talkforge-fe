import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String _getFlag(String? code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'de':
        return '🇩🇪';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      default:
        return '🇹🇷';
    }
  }

  static String _getLangName(String? code) {
    switch (code) {
      case 'en':
        return 'English (en)';
      case 'de':
        return 'Deutsch (de)';
      case 'es':
        return 'Español (es)';
      case 'fr':
        return 'Français (fr)';
      default:
        return 'Türkçe (tr)';
    }
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'tr':
        return 'Türkçe 🇹🇷';
      case 'en':
        return 'English 🇬🇧';
      case 'de':
        return 'Deutsch 🇩🇪';
      case 'es':
        return 'Español 🇪🇸';
      case 'fr':
        return 'Français 🇫🇷';
      default:
        return code.toUpperCase();
    }
  }

  Widget _settingsRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget valueChild,
    required Widget trailing,
    VoidCallback? onTap,
    bool showBottomBorder = true,
  }) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: showBottomBorder ? Border(bottom: BorderSide(color: c.bordSoft)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.accTx),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.schibstedGrotesk(fontSize: 11, color: c.tx3)),
                  const SizedBox(height: 2),
                  valueChild,
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _pickLanguage(BuildContext context, AuthProvider authProvider, String lang) {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        final languages = [
          {'code': 'tr', 'name': 'Türkçe (tr)', 'flag': '🇹🇷'},
          {'code': 'en', 'name': 'English (en)', 'flag': '🇬🇧'},
          {'code': 'de', 'name': 'Deutsch (de)', 'flag': '🇩🇪'},
          {'code': 'es', 'name': 'Español (es)', 'flag': '🇪🇸'},
          {'code': 'fr', 'name': 'Français (fr)', 'flag': '🇫🇷'},
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  AppTranslations.tr('language_pref', lang),
                  style: GoogleFonts.schibstedGrotesk(color: c.tx, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              ...languages.map((item) {
                final isSel = authProvider.language == item['code'];
                return ListTile(
                  leading: Text(item['flag']!, style: const TextStyle(fontSize: 18)),
                  title: Text(item['name']!, style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 14)),
                  trailing: isSel ? Icon(Icons.check_circle_rounded, color: c.accTx, size: 18) : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (item['code'] == authProvider.language) return;
                    try {
                      await authProvider.updateLanguage(item['code']!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: c.surf,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: c.acc),
                            ),
                            content: Text(
                              '${AppTranslations.tr('lang_updated', item['code']!)}: ${_getLanguageDisplayName(item['code']!)}',
                              style: GoogleFonts.schibstedGrotesk(color: c.tx, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${AppTranslations.tr('error', lang)}: ${e.toString().replaceAll("Exception: ", "")}'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = authProvider.language;
    final c = context.colors;
    final isMobile = MediaQuery.of(context).size.width < 800;
    final isDark = themeProvider.isDark;
    final nickname = authProvider.nickname ?? AppTranslations.tr('user', lang);
    final roleLabel = authProvider.role == 'admin'
        ? AppTranslations.tr('admin_role', lang)
        : AppTranslations.tr('user_role', lang);

    return SingleChildScrollView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 20, 16, 32)
          : const EdgeInsets.fromLTRB(36, 30, 36, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.tr('my_profile', lang),
                style: GoogleFonts.schibstedGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.tx),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surf,
                  border: Border.all(color: c.bordSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: c.accSoft,
                      child: Text(
                        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: c.accTx),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nickname, style: GoogleFonts.schibstedGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: c.tx)),
                          const SizedBox(height: 2),
                          Text(
                            '${authProvider.email ?? ''} · $roleLabel',
                            style: GoogleFonts.schibstedGrotesk(fontSize: 13, color: c.tx3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: c.surf,
                  border: Border.all(color: c.bordSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _settingsRow(
                      context: context,
                      icon: Icons.language,
                      label: AppTranslations.tr('language_pref', lang),
                      valueChild: Row(
                        children: [
                          Text(_getFlag(authProvider.language), style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            _getLangName(authProvider.language),
                            style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: c.tx),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.keyboard_arrow_down_rounded, color: c.tx3),
                      onTap: () => _pickLanguage(context, authProvider, lang),
                    ),
                    _settingsRow(
                      context: context,
                      icon: isDark ? Icons.dark_mode : Icons.light_mode,
                      label: 'Görünüm',
                      showBottomBorder: false,
                      valueChild: Text(
                        isDark ? 'Koyu tema' : 'Açık tema',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: c.tx),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: c.surf2,
                          border: Border.all(color: c.bord),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SegmentButton(label: 'Koyu', selected: isDark, onTap: themeProvider.setDark),
                            _SegmentButton(label: 'Açık', selected: !isDark, onTap: themeProvider.setLight),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => authProvider.logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(AppTranslations.tr('logout', lang), style: GoogleFonts.schibstedGrotesk(fontSize: 13.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerTx,
                  side: const BorderSide(color: AppColors.dangerBord),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.acc : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: GoogleFonts.schibstedGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.tx2,
          ),
        ),
      ),
    );
  }
}
