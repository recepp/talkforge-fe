import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'tr': return 'Türkçe 🇹🇷';
      case 'en': return 'English 🇬🇧';
      case 'de': return 'Deutsch 🇩🇪';
      case 'es': return 'Español 🇪🇸';
      case 'fr': return 'Français 🇫🇷';
      default: return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          AppTranslations.tr('my_profile', lang),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Avatar Placeholder
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF312E81),
                  child: Icon(
                    Icons.account_circle,
                    size: 80,
                    color: Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(height: 20),
                // Nickname
                Text(
                  authProvider.nickname ?? AppTranslations.tr('user', lang),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authProvider.role == 'admin'
                        ? Colors.amber.withOpacity(0.1)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: authProvider.role == 'admin'
                          ? Colors.amber.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    authProvider.role == 'admin'
                        ? AppTranslations.tr('admin_role', lang)
                        : AppTranslations.tr('user_role', lang),
                    style: GoogleFonts.inter(
                      color: authProvider.role == 'admin' ? Colors.amber : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                // User Details Rows
                Row(
                  children: [
                    const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.tr('email_address', lang),
                            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
                          ),
                          Text(
                            authProvider.email ?? '',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                // Language Preference Field with PopupMenuButton
                LayoutBuilder(
                  builder: (context, constraints) {
                    return PopupMenuButton<String>(
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 8),
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        maxWidth: constraints.maxWidth,
                      ),
                      color: const Color(0xFF1E293B),
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                      ),
                      onSelected: (String newLang) async {
                        if (newLang != authProvider.language) {
                          try {
                            await authProvider.updateLanguage(newLang);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  elevation: 8,
                                  backgroundColor: const Color(0xFF1E1B4B),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                                  ),
                                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  duration: const Duration(seconds: 3),
                                  content: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF818CF8),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${AppTranslations.tr('lang_updated', newLang)}: ${_getLanguageDisplayName(newLang)}',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 2500),
                                  content: Text('${AppTranslations.tr('error', lang)}: ${e.toString().replaceAll("Exception: ", "")}'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        final languages = [
                          {'code': 'tr', 'name': 'Türkçe (tr)', 'flag': '🇹🇷'},
                          {'code': 'en', 'name': 'English (en)', 'flag': '🇬🇧'},
                          {'code': 'de', 'name': 'Deutsch (de)', 'flag': '🇩🇪'},
                          {'code': 'es', 'name': 'Español (es)', 'flag': '🇪🇸'},
                          {'code': 'fr', 'name': 'Français (fr)', 'flag': '🇫🇷'},
                        ];
                        return languages.map((langItem) {
                          final isSel = authProvider.language == langItem['code'];
                          return PopupMenuItem<String>(
                            value: langItem['code'],
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF818CF8) : const Color(0xFF334155),
                                      ),
                                    ),
                                    child: Text(langItem['flag']!, style: const TextStyle(fontSize: 15)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      langItem['name']!,
                                      style: GoogleFonts.inter(
                                        color: isSel ? Colors.white : const Color(0xFFCBD5E1),
                                        fontSize: 14,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isSel)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF818CF8),
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language_outlined, color: Color(0xFF818CF8), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppTranslations.tr('language_pref', lang),
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        _getFlag(authProvider.language),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getLangName(authProvider.language),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Logout Button
                ElevatedButton.icon(
                  onPressed: () => authProvider.logout(),
                  icon: const Icon(Icons.logout),
                  label: Text(AppTranslations.tr('logout', lang)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _getFlag(String? code) {
    switch (code) {
      case 'en': return '🇬🇧';
      case 'de': return '🇩🇪';
      case 'es': return '🇪🇸';
      case 'fr': return '🇫🇷';
      default: return '🇹🇷';
    }
  }

  static String _getLangName(String? code) {
    switch (code) {
      case 'en': return 'English (en)';
      case 'de': return 'Deutsch (de)';
      case 'es': return 'Español (es)';
      case 'fr': return 'Français (fr)';
      default: return 'Türkçe (tr)';
    }
  }
}
