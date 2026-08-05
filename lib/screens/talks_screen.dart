import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import 'create_talk_dialog.dart';
import 'talk_detail_screen.dart';

class TalksScreen extends StatefulWidget {
  const TalksScreen({super.key});

  @override
  State<TalksScreen> createState() => _TalksScreenState();
}

class _TalksScreenState extends State<TalksScreen> {
  List<dynamic> _talks = [];
  bool _isLoading = true;
  String _error = '';
  Timer? _pollTimer;

  void _openCreateTalkDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateTalkDialog',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) => const CreateTalkDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    ).then((_) => _fetchTalks());
  }

  @override
  void initState() {
    super.initState();
    _fetchTalks();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTalks({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final talks = await ApiService.getTalkRequests();
      if (mounted) {
        setState(() {
          _talks = talks;
          _isLoading = false;
          _error = '';
        });
        _checkAndManagePolling();
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('401') ||
          err.contains('unauthorized') ||
          err.contains('oturum') ||
          err.contains('token') ||
          err.contains('headers') ||
          err.contains('iso-8859-1')) {
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      if (mounted && !silent) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _checkAndManagePolling() {
    final hasPendingOrProcessing = _talks.any((talk) {
      final status = talk['status'] as String? ?? '';
      return status == 'pending' || status == 'processing';
    });

    if (hasPendingOrProcessing) {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
        _fetchTalks(silent: true);
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _deleteTalk(int id, String topic) async {
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Text(
          AppTranslations.tr('delete', lang),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          AppTranslations.tr('confirm_delete', lang),
          style: GoogleFonts.inter(color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppTranslations.tr('cancel', lang),
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              AppTranslations.tr('delete', lang),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteTalkRequest(id);
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1800),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.tr('success', lang),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        _fetchTalks();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 2500),
              content: Text('${AppTranslations.tr('error', lang)}: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'processing':
        return const Color(0xFF3B82F6);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusText(String status, String lang) {
    switch (status) {
      case 'completed':
        return AppTranslations.tr('status_completed', lang);
      case 'processing':
        return AppTranslations.tr('status_generating', lang);
      case 'failed':
        return AppTranslations.tr('status_failed', lang);
      default:
        return AppTranslations.tr('status_pending', lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF131C31), Color(0xFF1A1D36)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppTranslations.tr('my_talks', lang),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 19,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _fetchTalks,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFCBD5E1)),
              tooltip: AppTranslations.tr('refresh', lang),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : _error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFF87171)),
                          const SizedBox(height: 16),
                          Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchTalks,
                            icon: const Icon(Icons.refresh),
                            label: Text(AppTranslations.tr('refresh', lang)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                : _talks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF334155), width: 1),
                              ),
                              child: const Icon(
                                Icons.mic_none_outlined,
                                size: 56,
                                color: Color(0xFF818CF8),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              AppTranslations.tr('no_talks', lang),
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE2E8F0),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppTranslations.tr('talks_subtitle', lang),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _openCreateTalkDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(AppTranslations.tr('new_talk', lang)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                elevation: 4,
                                shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _talks.length,
                        itemBuilder: (context, index) {
                          final talk = _talks[index];
                          final int id = talk['id'] as int;
                          final status = talk['status'] as String;
                          final statusColor = _getStatusColor(status);
                          final topic = talk['topic'] as String? ?? 'Konuşma Hazırlığı';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.75),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF334155).withOpacity(0.6),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TalkDetailScreen(talkNode: talk),
                                    ),
                                  ).then((_) => _fetchTalks());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(18.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4338CA).withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              AppTranslations.translateSpeechType(talk['speech_type'], lang),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFA5B4FC),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor.withOpacity(0.35)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _getStatusText(status, lang),
                                                  style: GoogleFonts.inter(
                                                    color: statusColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _deleteTalk(id, topic),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFFF87171),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        topic,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(color: Color(0xFF334155), height: 1, thickness: 0.8),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFF59E0B)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              talk['place'] ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFCBD5E1),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${talk['duration'] ?? 0} ${AppTranslations.tr("minutes", lang)}',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFCBD5E1),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Icon(Icons.language_outlined, size: 15, color: Color(0xFF34D399)),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppTranslations.translateLanguageName(talk['language'], lang),
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFCBD5E1),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateTalkDialog,
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            AppTranslations.tr('new_talk', lang),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
