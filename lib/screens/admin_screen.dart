import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  final bool showBackButton;

  const AdminScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _rooms = [];
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _loadAllData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.role != 'admin') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Yönetici yetkisi gereklidir.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAdminStats(),
        ApiService.getAdminUsers(),
        ApiService.getAdminRooms(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<dynamic>;
        _rooms = results[2] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required AppColors c,
    required String title,
    required String message,
    required Map<String, dynamic> user,
    required String actionButtonText,
    required Color actionColor,
    required IconData icon,
  }) async {
    final nickname = user['nickname'] as String? ?? 'Kullanıcı';
    final email = user['email'] as String? ?? '';
    final avatar = user['avatar'] as String? ?? '👤';
    final role = user['role'] as String? ?? 'user';
    final isSuspended = user['is_suspended'] as bool? ?? false;
    final talkCount = user['talk_count'] ?? 0;
    final geminiCount = user['gemini_call_count'] ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.bordSoft),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: actionColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: actionColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.tx,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: 14,
                  color: c.tx2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.bordSoft),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.surf,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bordSoft),
                          ),
                          alignment: Alignment.center,
                          child: Text(avatar, style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nickname,
                                style: GoogleFonts.schibstedGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.tx,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: GoogleFonts.schibstedGrotesk(
                                  fontSize: 12,
                                  color: c.tx3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: role == 'admin'
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                    : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: role == 'admin'
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                role == 'admin' ? 'ADMIN' : 'KULLANICI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: role == 'admin' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                            if (isSuspended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'ASKIDA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$talkCount konuşma · $geminiCount Gemini · ${_formatNumber((user['gemini_token_count'] as num?)?.toInt() ?? 0)} token',
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.tx3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Vazgeç',
                style: GoogleFonts.schibstedGrotesk(
                  fontWeight: FontWeight.w600,
                  color: c.tx2,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                actionButtonText,
                style: GoogleFonts.schibstedGrotesk(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _toggleUserRole(Map<String, dynamic> user) async {
    final email = (user['email'] as String? ?? '').toLowerCase();
    if (email == 'admin@talkforge.local') {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Ana yönetici hesabı (admin@talkforge.local) değiştirilemez.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    final currentRole = user['role'] as String? ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    final nickname = user['nickname'] as String? ?? 'Kullanıcı';
    final userId = user['id'] as int;

    final isGrantingAdmin = newRole == 'admin';
    final title = isGrantingAdmin ? 'Admin Rolü Verilsin mi?' : 'Admin Rolü Kaldırılsın mı?';
    final message = isGrantingAdmin
        ? '$nickname kullanıcısına Admin yetkisi vermek istediğinize emin misiniz?'
        : '$nickname kullanıcısının Admin yetkisini kaldırıp standart kullanıcı yapmak istediğinize emin misiniz?';

    final c = context.colors;
    final confirmed = await _showConfirmationDialog(
      context: context,
      c: c,
      title: title,
      message: message,
      user: user,
      actionButtonText: isGrantingAdmin ? 'Admin Yap' : 'Rolünü Değiştir',
      actionColor: isGrantingAdmin ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
      icon: isGrantingAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
    );

    if (!confirmed) return;

    try {
      final updated = await ApiService.updateAdminUser(userId, role: newRole);
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == userId);
        if (idx != -1) {
          _users[idx] = updated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Kullanıcı rolü güncellendi: $newRole'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  Future<void> _toggleUserSuspension(Map<String, dynamic> user) async {
    final email = (user['email'] as String? ?? '').toLowerCase();
    if (email == 'admin@talkforge.local') {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Ana yönetici hesabı (admin@talkforge.local) askıya alınamaz.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    final isSuspended = user['is_suspended'] as bool? ?? false;
    final newSuspended = !isSuspended;
    final nickname = user['nickname'] as String? ?? 'Kullanıcı';
    final userId = user['id'] as int;

    final title = newSuspended ? 'Hesap Askıya Alınsın mı?' : 'Hesap Askısı Kaldırılsın mı?';
    final message = newSuspended
        ? '$nickname kullanıcısının hesabını askıya almak istediğinize emin misiniz? Kullanıcı sisteme giriş yapamayacaktır.'
        : '$nickname kullanıcısının hesap askısını kaldırıp aktif etmek istediğinize emin misiniz?';

    final c = context.colors;
    final confirmed = await _showConfirmationDialog(
      context: context,
      c: c,
      title: title,
      message: message,
      user: user,
      actionButtonText: newSuspended ? 'Askıya Al' : 'Aktifleştir',
      actionColor: newSuspended ? Colors.redAccent : const Color(0xFF10B981),
      icon: newSuspended ? Icons.block_rounded : Icons.check_circle_outline_rounded,
    );

    if (!confirmed) return;

    try {
      final updated = await ApiService.updateAdminUser(userId, isSuspended: newSuspended);
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == userId);
        if (idx != -1) {
          _users[idx] = updated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(newSuspended ? 'Kullanıcı hesabı askıya alındı' : 'Hesap askısı kaldırıldı'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  String _getTierName(String? tier) {
    switch ((tier ?? '').toLowerCase()) {
      case 'pro':
        return 'Pro Paket';
      case 'enterprise':
        return 'Enterprise Paket';
      case 'free':
      default:
        return 'Ücretsiz Paket';
    }
  }

  Color _getTierColor(String? tier) {
    switch ((tier ?? '').toLowerCase()) {
      case 'pro':
        return const Color(0xFFA855F7);
      case 'enterprise':
        return const Color(0xFFF59E0B);
      case 'free':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day.$month.$year';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _dialogDetailRow(
    AppColors c, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.bordSoft.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: valueColor ?? c.tx3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.schibstedGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: c.tx2),
            ),
          ),
          const SizedBox(width: 8),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (valueColor ?? c.acc).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (valueColor ?? c.acc).withValues(alpha: 0.3)),
              ),
              child: Text(
                value,
                style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor ?? c.acc),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.schibstedGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? c.tx,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showUserInfoDialog(Map<String, dynamic> initialUser) async {
    final c = context.colors;
    Map<String, dynamic> user = Map<String, dynamic>.from(initialUser);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final nickname = user['nickname'] as String? ?? 'Kullanıcı';
            final email = (user['email'] as String? ?? '').toLowerCase();
            final avatar = user['avatar'] as String? ?? '👤';
            final role = user['role'] as String? ?? 'user';
            final isAdmin = role == 'admin';
            final isSuspended = user['is_suspended'] as bool? ?? false;
            final isSuperAdmin = email == 'admin@talkforge.local';
            final tier = user['subscription_tier'] as String? ?? 'free';
            final talkCount = (user['talk_count'] as num?)?.toInt() ?? 0;
            final geminiCount = (user['gemini_call_count'] as num?)?.toInt() ?? 0;
            final tokenCount = (user['gemini_token_count'] as num?)?.toInt() ?? 0;
            final language = user['language'] as String? ?? 'tr';
            final createdAt = user['created_at'] as String? ?? '';
            final userId = user['id'] as int;

            final tierName = _getTierName(tier);
            final tierColor = _getTierColor(tier);

            return AlertDialog(
              backgroundColor: c.surf,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: c.bordSoft),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.acc.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.acc.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.badge_rounded, color: c.acc, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kullanıcı Bilgileri',
                      style: GoogleFonts.schibstedGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.tx,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close_rounded, color: c.tx3, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header profile card inside dialog
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.bordSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: c.surf,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.bordSoft),
                              ),
                              alignment: Alignment.center,
                              child: Text(avatar, style: const TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          nickname,
                                          style: GoogleFonts.schibstedGrotesk(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: c.tx,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAdmin ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isAdmin ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          isAdmin ? 'ADMIN' : 'KULLANICI',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                      if (isSuspended) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                          ),
                                          child: const Text(
                                            'ASKIDA',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx2),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Detail items
                      _dialogDetailRow(
                        c,
                        icon: Icons.workspace_premium_rounded,
                        label: 'Aktif Paket',
                        value: tierName,
                        valueColor: tierColor,
                        isBadge: true,
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: Icons.token_rounded,
                        label: 'Kullanılan Toplam Token',
                        value: _formatNumber(tokenCount),
                        valueColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: Icons.auto_awesome_rounded,
                        label: 'Gemini Çağrı Sayısı',
                        value: '$geminiCount çağrı',
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: Icons.graphic_eq_rounded,
                        label: 'Toplam Konuşma',
                        value: '$talkCount konuşma',
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: Icons.language_rounded,
                        label: 'Dil Tercihi',
                        value: language.toUpperCase(),
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: Icons.calendar_today_rounded,
                        label: 'Kayıt Tarihi',
                        value: _formatDate(createdAt),
                      ),
                      const SizedBox(height: 8),
                      _dialogDetailRow(
                        c,
                        icon: isSuspended ? Icons.block_rounded : Icons.check_circle_rounded,
                        label: 'Hesap Durumu',
                        value: isSuspended ? 'Askıda' : 'Aktif',
                        valueColor: isSuspended ? Colors.redAccent : const Color(0xFF10B981),
                      ),

                      if (!isSuperAdmin) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Kullanıcı İşlemleri',
                          style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: c.tx3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final newRole = isAdmin ? 'user' : 'admin';
                                  try {
                                    final updated = await ApiService.updateAdminUser(userId, role: newRole);
                                    setState(() {
                                      final idx = _users.indexWhere((u) => u['id'] == userId);
                                      if (idx != -1) _users[idx] = updated;
                                    });
                                    setDialogState(() => user = Map<String, dynamic>.from(updated));
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Rol güncellenemedi: ${e.toString()}'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(isAdmin ? Icons.person_rounded : Icons.admin_panel_settings_rounded, size: 16),
                                label: Text(
                                  isAdmin ? 'User Yap' : 'Admin Yap',
                                  style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.tx,
                                  side: BorderSide(color: c.bordSoft),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final newSuspended = !isSuspended;
                                  try {
                                    final updated = await ApiService.updateAdminUser(userId, isSuspended: newSuspended);
                                    setState(() {
                                      final idx = _users.indexWhere((u) => u['id'] == userId);
                                      if (idx != -1) _users[idx] = updated;
                                    });
                                    setDialogState(() => user = Map<String, dynamic>.from(updated));
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Durum güncellenemedi: ${e.toString()}'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(isSuspended ? Icons.check_circle_rounded : Icons.block_rounded, size: 16),
                                label: Text(
                                  isSuspended ? 'Aktifleştir' : 'Askıya Al',
                                  style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSuspended ? const Color(0xFF10B981) : Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Kapat',
                    style: GoogleFonts.schibstedGrotesk(color: c.tx2, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.watch<AuthProvider>();
    final lang = auth.language;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surf,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.tx),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: AppTranslations.tr('back', lang),
              )
            : null,
        title: Row(
          children: [
            Text(
              AppTranslations.tr('admin_panel', lang),
              style: GoogleFonts.schibstedGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.tx,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.acc.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.acc.withOpacity(0.3)),
              ),
              child: Text(
                'Yönetim',
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.accTx,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.tx2),
            onPressed: _loadAllData,
            tooltip: AppTranslations.tr('refresh', lang),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.bordSoft)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: c.accTx,
              unselectedLabelColor: c.tx3,
              indicatorColor: c.accTx,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insights_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(AppTranslations.tr('admin_stats', lang)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(AppTranslations.tr('admin_users', lang)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.meeting_room_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(AppTranslations.tr('admin_rooms', lang)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.accTx))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.schibstedGrotesk(fontSize: 14, color: c.tx2),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAllData,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(AppTranslations.tr('refresh', lang)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.acc,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatsTab(c, lang),
                    _buildUsersTab(c, lang),
                    _buildRoomsTab(c, lang),
                  ],
                ),
    );
  }

  Widget _buildStatsTab(AppColors c, String lang) {
    if (_stats == null) return const SizedBox.shrink();

    final totalUsers = _stats!['total_users'] ?? 0;
    final totalTalks = _stats!['total_talks'] ?? 0;
    final totalRooms = _stats!['total_rooms'] ?? _rooms.length;
    final quotaExceededUsers = _stats!['quota_exceeded_users'] ?? _users.where((u) => u['is_suspended'] == true).length;
    final geminiToday = _stats!['gemini_calls_today'] ?? 0;
    final geminiMonth = _stats!['gemini_calls_month'] ?? 0;
    final geminiTotal = _stats!['gemini_calls_total'] ?? 0;
    final geminiTokensToday = (_stats!['gemini_tokens_today'] as num?)?.toInt() ?? 0;
    final geminiTokensMonth = (_stats!['gemini_tokens_month'] as num?)?.toInt() ?? 0;
    final geminiTokensTotal = (_stats!['gemini_tokens_total'] as num?)?.toInt() ?? 0;

    final statusCounts = Map<String, dynamic>.from(_stats!['status_counts'] ?? {});
    final pending = statusCounts['pending'] ?? 0;
    final processing = statusCounts['processing'] ?? 0;
    final completed = statusCounts['completed'] ?? 0;
    final failed = statusCounts['failed'] ?? 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;
    final crossAxisCount = screenWidth > 1100 ? 4 : 2;
    final childAspectRatio = screenWidth > 1100
        ? 2.1
        : (screenWidth > 650 ? 2.3 : 2.3);

    final paddingVal = isMobile ? 12.0 : 24.0;
    final spacingVal = isMobile ? 8.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(paddingVal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title with live indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Genel Bakış',
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: c.tx,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Canlı Veri',
                      style: GoogleFonts.schibstedGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Stat Cards Grid
          GridView.count(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacingVal,
            mainAxisSpacing: spacingVal,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard(
                c: c,
                title: 'Toplam Kullanıcı',
                value: '$totalUsers',
                subtitle: 'Kayıtlı hesap',
                icon: Icons.group_rounded,
                accentColor: const Color(0xFF3B82F6),
                isMobile: isMobile,
              ),
              _statCard(
                c: c,
                title: 'Toplam Konuşma',
                value: '$totalTalks',
                subtitle: 'Sesli diyalog',
                icon: Icons.graphic_eq_rounded,
                accentColor: const Color(0xFFA855F7),
                isMobile: isMobile,
              ),
              _statCard(
                c: c,
                title: 'Toplam Oda',
                value: '$totalRooms',
                subtitle: 'Topluluk odaları',
                icon: Icons.meeting_room_rounded,
                accentColor: const Color(0xFFF59E0B),
                isMobile: isMobile,
              ),
              _statCard(
                c: c,
                title: 'Kotası Dolan',
                value: '$quotaExceededUsers',
                subtitle: 'Kısıtlı hesaplar',
                icon: Icons.no_accounts_rounded,
                accentColor: const Color(0xFFEF4444),
                isMobile: isMobile,
              ),
            ],
          ),

          SizedBox(height: isMobile ? 14 : 28),

          // Gemini API Usage Banner Container
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.bordSoft),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                      ),
                      child: Icon(Icons.bolt_rounded, color: const Color(0xFFF59E0B), size: isMobile ? 18 : 22),
                    ),
                    SizedBox(width: isMobile ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gemini API Kullanımı',
                            style: GoogleFonts.schibstedGrotesk(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w700,
                              color: c.tx,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Google Gemini AI genel çağrı ve harcanan token performansı',
                            style: GoogleFonts.schibstedGrotesk(fontSize: 11, color: c.tx2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 20),
                const Divider(height: 1),
                SizedBox(height: isMobile ? 12 : 20),
                Row(
                  children: [
                    _geminiMetricTile(
                      c,
                      label: 'Toplam',
                      calls: geminiTotal,
                      tokens: geminiTokensTotal,
                      color: const Color(0xFF6366F1),
                      isMobile: isMobile,
                    ),
                    SizedBox(width: isMobile ? 8 : 16),
                    _geminiMetricTile(
                      c,
                      label: 'Bu Ay',
                      calls: geminiMonth,
                      tokens: geminiTokensMonth,
                      color: const Color(0xFF10B981),
                      isMobile: isMobile,
                    ),
                    SizedBox(width: isMobile ? 8 : 16),
                    _geminiMetricTile(
                      c,
                      label: 'Bugün',
                      calls: geminiToday,
                      tokens: geminiTokensToday,
                      color: const Color(0xFFF59E0B),
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: isMobile ? 14 : 28),

          // Conversation Status Distribution
          Text(
            'Konuşma Durumu Dağılımı',
            style: GoogleFonts.schibstedGrotesk(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: c.tx,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 14),
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.bordSoft),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-segment progress bar at top
                if (totalTalks > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          if (completed > 0)
                            Expanded(
                              flex: completed,
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (processing > 0)
                            Expanded(
                              flex: processing,
                              child: Container(color: const Color(0xFF3B82F6)),
                            ),
                          if (pending > 0)
                            Expanded(
                              flex: pending,
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                          if (failed > 0)
                            Expanded(
                              flex: failed,
                              child: Container(color: const Color(0xFFEF4444)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 20),
                ],

                // Status rows
                _statusRow(c, 'Tamamlandı', completed, totalTalks, const Color(0xFF10B981), Icons.check_circle_rounded),
                const SizedBox(height: 14),
                _statusRow(c, 'İşleniyor', processing, totalTalks, const Color(0xFF3B82F6), Icons.sync_rounded),
                const SizedBox(height: 14),
                _statusRow(c, 'Bekliyor', pending, totalTalks, const Color(0xFFF59E0B), Icons.hourglass_empty_rounded),
                const SizedBox(height: 14),
                _statusRow(c, 'Başarısız', failed, totalTalks, const Color(0xFFEF4444), Icons.error_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required AppColors c,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 18,
        vertical: isMobile ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: c.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accentColor, size: isMobile ? 18 : 24),
          ),
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: c.tx2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.w800,
                    color: c.tx,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: isMobile ? 9.5 : 11,
                    color: c.tx3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _geminiMetricTile(
    AppColors c, {
    required String label,
    required int calls,
    required int tokens,
    required Color color,
    bool isMobile = false,
  }) {
    final tokensStr = _formatNumber(tokens);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 10 : 14),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isMobile ? 6 : 8,
                  height: isMobile ? 6 : 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: isMobile ? 4 : 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.schibstedGrotesk(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: c.tx2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    tokensStr,
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: c.tx,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'token',
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: isMobile ? 12 : 13, color: c.tx3),
                const SizedBox(width: 2),
                Text(
                  '$calls çağrı',
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: isMobile ? 10.5 : 11.5,
                    fontWeight: FontWeight.w500,
                    color: c.tx2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(AppColors c, String label, int count, int total, Color color, IconData icon) {
    final double pct = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: c.tx),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count (${(pct * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: c.bg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab(AppColors c, String lang) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final filteredUsers = _users.where((u) {
      final email = (u['email'] as String? ?? '').toLowerCase();
      final nickname = (u['nickname'] as String? ?? '').toLowerCase();
      final q = _userSearchQuery.toLowerCase();
      return email.contains(q) || nickname.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
          child: TextField(
            onChanged: (val) => setState(() => _userSearchQuery = val),
            style: GoogleFonts.schibstedGrotesk(color: c.tx),
            decoration: InputDecoration(
              hintText: 'Kullanıcı e-posta veya rumuz ara...',
              hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3),
              prefixIcon: Icon(Icons.search_rounded, color: c.tx3),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: c.tx3),
                      onPressed: () => setState(() => _userSearchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: c.surf,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.bordSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.bordSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.acc),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 48, color: c.tx3),
                      const SizedBox(height: 12),
                      Text('Kullanıcı bulunamadı.', style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 4),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index] as Map<String, dynamic>;
                    final isSuspended = user['is_suspended'] as bool? ?? false;
                    final role = user['role'] as String? ?? 'user';
                    final isAdmin = role == 'admin';
                    return Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: c.surf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSuspended ? Colors.red.withOpacity(0.5) : c.bordSoft,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: isMobile ? 38 : 44,
                                height: isMobile ? 38 : 44,
                                decoration: BoxDecoration(
                                  color: c.bg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.bordSoft),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  user['avatar'] as String? ?? '👤',
                                  style: TextStyle(fontSize: isMobile ? 18 : 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user['nickname'] as String? ?? '',
                                            style: GoogleFonts.schibstedGrotesk(
                                              fontSize: isMobile ? 15 : 16,
                                              fontWeight: FontWeight.w700,
                                              color: c.tx,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isAdmin ? const Color(0xFFF59E0B).withOpacity(0.15) : const Color(0xFF3B82F6).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isAdmin ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            isAdmin ? 'ADMIN' : 'KULLANICI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                        if (isSuspended) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                                            ),
                                            child: const Text(
                                              'ASKIDA',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user['email'] as String? ?? '',
                                      style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx2),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Kullanıcı Bilgileri',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _showUserInfoDialog(user),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: c.acc.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: c.acc.withValues(alpha: 0.3)),
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: c.accTx,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomsTab(AppColors c, String lang) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room_outlined, size: 48, color: c.tx3),
            const SizedBox(height: 12),
            Text('Henüz oda bulunmuyor.', style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: _rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final room = _rooms[index] as Map<String, dynamic>;
        final name = room['name'] as String? ?? 'İsimsiz Oda';
        final ownerEmail = room['owner_email'] as String? ?? '';
        final ownerNick = room['owner_nickname'] as String? ?? '';
        final memberCount = room['member_count'] ?? 0;
        final talkCount = room['talk_count'] ?? 0;

        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: c.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.bordSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.acc.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.acc.withOpacity(0.25)),
                          ),
                          child: Icon(Icons.meeting_room_rounded, color: c.accTx, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.schibstedGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.tx,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sahibi: $ownerNick ($ownerEmail)',
                                style: GoogleFonts.schibstedGrotesk(fontSize: 11, color: c.tx2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.bordSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_rounded, size: 13, color: c.tx2),
                              const SizedBox(width: 4),
                              Text('$memberCount üye', style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: c.tx)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.bordSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: c.tx2),
                              const SizedBox(width: 4),
                              Text('$talkCount konuşma', style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: c.tx)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.acc.withOpacity(0.25)),
                      ),
                      child: Icon(Icons.meeting_room_rounded, color: c.accTx, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.schibstedGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.tx,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sahibi: $ownerNick ($ownerEmail)',
                            style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx2),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.bordSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_rounded, size: 14, color: c.tx2),
                              const SizedBox(width: 4),
                              Text('$memberCount üye', style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: c.tx)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.bordSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: c.tx2),
                              const SizedBox(width: 4),
                              Text('$talkCount konuşma', style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: c.tx)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
