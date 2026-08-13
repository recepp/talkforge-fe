import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  final bool showBackButton;

  const PremiumScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = true;
  List<dynamic> _plans = [];
  Map<String, dynamic>? _userSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    setState(() => _isLoading = true);

    try {
      final plans = await ApiService.getSubscriptionPlans(langCode: lang);
      final sub = await ApiService.getUserSubscription().catchError((_) => <String, dynamic>{});
      if (mounted) {
        setState(() {
          _plans = plans;
          _userSub = sub;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPaymentNoticeDialog(BuildContext context, String tierName) {
    final c = context.colors;
    final lang = Provider.of<AuthProvider>(context, listen: false).language;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: c.surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.bord),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c.acc, const Color(0xFF818CF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.acc.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppTranslations.tr('payment_notice_title', lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: c.tx,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppTranslations.tr('payment_notice_msg', lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 14,
                      height: 1.45,
                      color: c.tx2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.acc,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppTranslations.tr('got_it', lang),
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
    final currentTier = _userSub?['subscription_tier'] ?? authProvider.subscriptionTier;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: widget.showBackButton
          ? AppBar(
              backgroundColor: c.surf,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.tx),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                AppTranslations.tr('premium', lang),
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.tx,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: c.bordSoft, height: 1),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: c.acc,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── HEADER BANNER ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.surf,
                        c.accSoft.withValues(alpha: 0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.accSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.accSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.acc.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.workspace_premium, color: c.acc, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    AppTranslations.tr('premium_title', lang),
                                    style: GoogleFonts.schibstedGrotesk(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: c.tx,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.accSoft,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: c.acc.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '${AppTranslations.tr('current_plan', lang)}: ${currentTier.toUpperCase()}',
                                    style: GoogleFonts.schibstedGrotesk(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.accTx,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppTranslations.tr('premium_subtitle', lang),
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 13.5,
                                color: c.tx2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── PLAN CARDS GRID / LIST ──────────────────────────────────
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: c.acc),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 850;
                      final plansList = _plans.isNotEmpty ? _plans : _getFallbackPlans(lang);

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: plansList.map((p) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: _buildPlanCard(context, p, currentTier),
                              ),
                            );
                          }).toList(),
                        );
                      }

                      return Column(
                        children: plansList.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildPlanCard(context, p, currentTier),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, dynamic plan, String currentTier) {
    final c = context.colors;
    final lang = Provider.of<AuthProvider>(context, listen: false).language;

    final String tier = plan['tier'] ?? plan['id'] ?? 'free';
    final String name = plan['name'] ?? 'Plan';
    final String price = plan['price'] ?? '\$0';
    final String period = plan['period'] ?? '/ Ay';
    final String badge = plan['badge'] ?? '';
    final String description = plan['description'] ?? '';
    final List<dynamic> features = plan['features'] ?? [];
    final bool isCurrent = currentTier.toLowerCase() == tier.toLowerCase();

    return InkWell(
      onTap: isCurrent ? null : () => _showPaymentNoticeDialog(context, name),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent ? c.acc : c.bord,
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: c.acc.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent ? c.accSoft : c.surf2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent ? c.acc.withValues(alpha: 0.5) : c.bordSoft,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? c.accTx : c.tx2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    name,
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.tx,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price,
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: isCurrent ? c.accTx : c.tx,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        period,
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 13.5,
                          color: c.tx3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 13,
                      color: c.tx2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Features List
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f.toString(),
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 13,
                                color: c.tx,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isCurrent
                          ? null
                          : () => _showPaymentNoticeDialog(context, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrent ? c.acc : c.surf2,
                        foregroundColor: isCurrent ? Colors.white : c.tx,
                        disabledBackgroundColor: c.acc,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrent ? c.acc : c.bord,
                          ),
                        ),
                        elevation: isCurrent ? 4 : 0,
                      ),
                      child: Text(
                        isCurrent
                            ? AppTranslations.tr('current_plan', lang)
                            : (plan['button_text'] ?? AppTranslations.tr('subscribe_now', lang)),
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getFallbackPlans(String lang) {
    return [
      {
        'id': 'free',
        'tier': 'free',
        'name': 'Ücretsiz / Standart',
        'price': '₺0',
        'period': '/ Ay',
        'badge': '',
        'description': 'TalkForge AI konuşma simülasyonlarını keşfetmek isteyen bireysel kullanıcılar için başlangıç paketi.',
        'features': [
          'Günlük 20 / Aylık 300 Konuşma Senaryosu',
          'Günlük 30.000 / Aylık 750.000 Token Limiti',
          'En Fazla 3 Ekip Odası Katılımı',
          'Temel Hitabet Şablonları & Rol Yapma',
          'Standart AI Yanıt Süresi',
        ],
        'is_popular': false,
        'button_text': 'Mevcut Planınız',
      },
      {
        'id': 'pro',
        'tier': 'pro',
        'name': 'Pro Aylık',
        'price': '\$5',
        'period': '/ Ay',
        'badge': 'En Popüler 🔥',
        'description': 'Hitabetini ve ikna kabiliyetini üst seviyeye taşımak isteyen profesyoneller için 3 kat limit.',
        'features': [
          'Günlük 60 / Aylık 900 Konuşma Senaryosu (3x)',
          'Günlük 90.000 / Aylık 2.250.000 Token Limiti (3x)',
          'En Fazla 9 Ekip Odası Katılımı (3x)',
          'İleri Düzey İkna & İtiraz Yanıtlama',
          'Yüksek Hızlı Gemini 1.5 Pro AI Yanıt Süresi',
          '7/24 Öncelikli Konuşma Çevirileri',
        ],
        'is_popular': true,
        'button_text': "Pro'ya Yükselt",
      },
      {
        'id': 'enterprise',
        'tier': 'enterprise',
        'name': 'Kurumsal',
        'price': '\$10',
        'period': '/ Ay',
        'badge': 'Kurumsal ⭐',
        'description': 'Geniş ekipler, kurumlar ve organizasyonlar için 10 kat devasa limit paketi.',
        'features': [
          'Günlük 200 / Aylık 3.000 Konuşma Senaryosu (10x)',
          'Günlük 300.000 / Aylık 7.500.000 Token Limiti (10x)',
          'En Fazla 30 Ekip Odası Katılımı (10x)',
          'Özel Şirket İçi Sistem İstemleri (Prompts)',
          '7/24 Özel Müşteri Temsilcisi & Destek',
          'Detaylı Kullanım İstatistikleri & Raporlama',
        ],
        'is_popular': false,
        'button_text': "Kurumsal'a Geç",
      },
    ];
  }
}
