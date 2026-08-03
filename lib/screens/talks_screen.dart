import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'create_talk_dialog.dart';
import 'create_talk_screen.dart';
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
      if (mounted && !silent) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Konuşmayı Sil',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          '"$topic" başlıklı konuşmayı ve bağlı tüm sürüm geçmişini silmek istediğinizden emin misiniz?',
          style: GoogleFonts.inter(
            color: const Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(
              'Sil',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Konuşma başarıyla silindi',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme işlemi başarısız: $e'),
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
        return const Color(0xFF10B981); // Emerald Green
      case 'processing':
        return const Color(0xFF3B82F6); // Blue
      case 'failed':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFFF59E0B); // Amber/Orange for pending
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Tamamlandı';
      case 'processing':
        return 'Hazırlanıyor';
      case 'failed':
        return 'Başarısız';
      default:
        return 'Sırada Bekliyor';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Konuşma Hazırlıklarım',
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
              tooltip: 'Yenile',
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
                            label: const Text('Tekrar Dene'),
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
                              'Henüz bir konuşma hazırlığı bulunmuyor.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE2E8F0),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yeni bir yapay zeka konuşma metni oluşturmak için başlayın.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _openCreateTalkDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Yeni Konuşma Başlat'),
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
                                      // Top Header: Type Tag, Status Chip, Delete Button
                                      Row(
                                        children: [
                                          // Speech Type Tag
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4338CA).withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              talk['speech_type'] ?? 'Genel Konuşma',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFA5B4FC),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Status Chip
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
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: statusColor.withOpacity(0.5),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _getStatusText(status),
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
                                          // Delete Action Button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _deleteTalk(id, topic),
                                              borderRadius: BorderRadius.circular(10),
                                              hoverColor: Colors.red.withOpacity(0.15),
                                              splashColor: Colors.red.withOpacity(0.2),
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
                                      // Topic Title
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
                                      // Details Row (Place, Duration, Language)
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
                                            '${talk['duration'] ?? 0} dk',
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
                                            talk['language'] ?? 'Türkçe',
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
            'Yeni Konuşma',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
