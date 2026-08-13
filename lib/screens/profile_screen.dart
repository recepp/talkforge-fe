import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/navigation_persistence.dart';
import 'admin_screen.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = false;
  String _usageError = '';
  bool _isQuotaExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      _isLoadingUsage = true;
      _usageError = '';
    });
    try {
      final stats = await ApiService.getUserUsage();
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _isLoadingUsage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usageError = e.toString().replaceAll('Exception: ', '');
          _isLoadingUsage = false;
        });
      }
    }
  }

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
      case 'ar':
        return '🇸🇦';
      case 'ru':
        return '🇷🇺';
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
      case 'ar':
        return 'العربية (ar)';
      case 'ru':
        return 'Русский (ru)';
      default:
        return 'Türkçe (tr)';
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final languages = [
          {'code': 'tr', 'name': 'Türkçe (tr)', 'flag': '🇹🇷'},
          {'code': 'en', 'name': 'English (en)', 'flag': '🇬🇧'},
          {'code': 'de', 'name': 'Deutsch (de)', 'flag': '🇩🇪'},
          {'code': 'es', 'name': 'Español (es)', 'flag': '🇪🇸'},
          {'code': 'fr', 'name': 'Français (fr)', 'flag': '🇫🇷'},
          {'code': 'ar', 'name': 'العربية (ar)', 'flag': '🇸🇦'},
          {'code': 'ru', 'name': 'Русский (ru)', 'flag': '🇷🇺'},
        ];
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: c.bordSoft, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.bord,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.language_rounded, color: c.accTx, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            AppTranslations.tr('language_pref', lang),
                            style: GoogleFonts.schibstedGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: c.tx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: c.bordSoft, height: 1),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: languages.map((l) {
                            final isSelected = authProvider.language == l['code'];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  Navigator.of(sheetContext).pop();
                                  await authProvider.updateLanguage(l['code']!);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? c.accSoft : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(l['flag']!, style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          l['name']!,
                                          style: GoogleFonts.schibstedGrotesk(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? c.accTx : c.tx,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: c.acc,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                        )
                                      else
                                        Icon(Icons.chevron_right_rounded, color: c.tx3, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuotaProgressItem({
    required BuildContext context,
    required String label,
    required int used,
    required int limit,
    required int remaining,
    required bool isToken,
    required String lang,
  }) {
    final c = context.colors;
    final double ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    Color progressColor = const Color(0xFF3B82F6); // Blue
    if (ratio >= 0.90) {
      progressColor = const Color(0xFFEF4444); // Red
    } else if (ratio >= 0.75) {
      progressColor = const Color(0xFFF59E0B); // Amber
    }

    final String usedStr = isToken ? _formatNumber(used) : used.toString();
    final String limitStr = isToken ? _formatNumber(limit) : limit.toString();
    final String remainingStr = isToken ? _formatNumber(remaining) : remaining.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.tx),
              ),
            ),
            RichText(
              text: TextSpan(
                style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx2),
                children: [
                  TextSpan(text: '$usedStr / $limitStr', style: TextStyle(fontWeight: FontWeight.w700, color: progressColor)),
                  TextSpan(text: ' (${AppTranslations.tr('remaining', lang)}: $remainingStr)', style: TextStyle(color: c.tx3, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: c.surf2,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      final val = number / 1000000;
      return val % 1 == 0 ? '${val.toInt()}M' : '${val.toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      final val = number / 1000;
      return val % 1 == 0 ? '${val.toInt()}k' : '${val.toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  Widget _buildQuotaCard(BuildContext context, String lang) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surf,
        border: Border.all(color: c.bordSoft),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isQuotaExpanded = !_isQuotaExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr('quota_usage_title', lang),
                        style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: c.tx),
                      ),
                      Text(
                        'Gemini API günlük kota tüketimi',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 11.5, color: c.tx3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadUsageStats,
                  tooltip: 'Yenile',
                  icon: _isLoadingUsage
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.acc))
                      : Icon(Icons.refresh_rounded, size: 18, color: c.tx3),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isQuotaExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.tx3,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isQuotaExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Divider(color: c.bordSoft, height: 1),
                      const SizedBox(height: 16),

                      if (_usageError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_usageError, style: TextStyle(color: AppColors.dangerTx, fontSize: 12)),
                        )
                      else if (_usageStats != null) ...[
                        _buildQuotaProgressItem(
                          context: context,
                          label: AppTranslations.tr('daily_tokens', lang),
                          used: (_usageStats!['daily_tokens_used'] as num?)?.toInt() ?? 0,
                          limit: (_usageStats!['daily_tokens_limit'] as num?)?.toInt() ?? 30000,
                          remaining: (_usageStats!['daily_tokens_remaining'] as num?)?.toInt() ?? 0,
                          isToken: true,
                          lang: lang,
                        ),
                        const SizedBox(height: 14),
                        _buildQuotaProgressItem(
                          context: context,
                          label: AppTranslations.tr('daily_edits', lang),
                          used: (_usageStats!['daily_edits_used'] as num?)?.toInt() ?? 0,
                          limit: (_usageStats!['daily_edits_limit'] as num?)?.toInt() ?? 20,
                          remaining: (_usageStats!['daily_edits_remaining'] as num?)?.toInt() ?? 0,
                          isToken: false,
                          lang: lang,
                        ),
                        const SizedBox(height: 14),
                        _buildQuotaProgressItem(
                          context: context,
                          label: AppTranslations.tr('daily_creates', lang),
                          used: (_usageStats!['daily_creates_used'] as num?)?.toInt() ?? 0,
                          limit: (_usageStats!['daily_creates_limit'] as num?)?.toInt() ?? 5,
                          remaining: (_usageStats!['daily_creates_remaining'] as num?)?.toInt() ?? 0,
                          isToken: false,
                          lang: lang,
                        ),
                        const SizedBox(height: 14),
                        _buildQuotaProgressItem(
                          context: context,
                          label: AppTranslations.tr('room_limit', lang),
                          used: (_usageStats!['rooms_used'] as num?)?.toInt() ?? 0,
                          limit: (_usageStats!['rooms_limit'] as num?)?.toInt() ?? 1,
                          remaining: (_usageStats!['rooms_remaining'] as num?)?.toInt() ?? 0,
                          isToken: false,
                          lang: lang,
                        ),
                      ] else ...[
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
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
    final currentTier = authProvider.subscriptionTier;

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
              const SizedBox(height: 14),
              _buildQuotaCard(context, lang),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: c.surf,
                  border: Border.all(color: c.bordSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (authProvider.role == 'admin')
                      _settingsRow(
                        context: context,
                        icon: Icons.admin_panel_settings_outlined,
                        label: AppTranslations.tr('admin_panel', lang),
                        valueChild: Text(
                          'Kullanıcı & Sistem Yönetimi',
                          style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: c.tx),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: c.tx3),
                        onTap: () async {
                          NavigationPersistence.saveState(tabIndex: 4);
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminScreen(showBackButton: true)),
                          );
                          NavigationPersistence.saveState(tabIndex: 3);
                        },
                      ),
                    _settingsRow(
                      context: context,
                      icon: Icons.workspace_premium_outlined,
                      label: AppTranslations.tr('premium', lang),
                      valueChild: Text(
                        'Abonelik & Paket Detayları',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: c.tx),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: c.tx3),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PremiumScreen(showBackButton: true)),
                        );
                      },
                    ),
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
                      label: AppTranslations.tr('appearance', lang),
                      showBottomBorder: false,
                      valueChild: Text(
                        isDark ? AppTranslations.tr('dark_theme', lang) : AppTranslations.tr('light_theme', lang),
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
                            _SegmentButton(label: AppTranslations.tr('dark', lang), selected: isDark, onTap: themeProvider.setDark),
                            _SegmentButton(label: AppTranslations.tr('light', lang), selected: !isDark, onTap: themeProvider.setLight),
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
