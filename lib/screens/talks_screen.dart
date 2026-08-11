import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'create_talk_dialog.dart';
import 'talk_detail_screen.dart';
import '../services/navigation_persistence.dart';

const _filterKeys = ['filter_all', 'filter_ready', 'filter_generating', 'filter_shared'];

class TalksScreen extends StatefulWidget {
  const TalksScreen({super.key});

  @override
  State<TalksScreen> createState() => TalksScreenState();
}

class TalksScreenState extends State<TalksScreen> {
  List<dynamic> _talks = [];
  bool _isLoading = true;
  String _error = '';
  Timer? _pollTimer;
  String _filterKey = 'filter_all';
  String _search = '';

  /// Public so the app shell (sidebar button / mobile FAB) can trigger it.
  void openCreateTalkDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateTalkDialog',
      barrierColor: Colors.black.withValues(alpha: 0.65),
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
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.bord),
        ),
        title: Text(
          AppTranslations.tr('delete', lang),
          style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.bold, color: c.tx),
        ),
        content: Text(
          AppTranslations.tr('confirm_delete', lang),
          style: GoogleFonts.schibstedGrotesk(color: c.tx2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppTranslations.tr('cancel', lang),
              style: GoogleFonts.schibstedGrotesk(color: c.tx3),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              AppTranslations.tr('delete', lang),
              style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.failed,
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
        await ApiService.deleteTalkRequest(id, cascade: true);
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
                    style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: AppColors.completed,
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

  /// Re-submits a failed talk with its original parameters.
  Future<void> _retryTalk(Map<String, dynamic> talk) async {
    try {
      await ApiService.createTalkRequest(
        mode: 'new',
        language: talk['language'] as String?,
        place: talk['place'] as String?,
        topic: talk['topic'] as String?,
        speechType: talk['speech_type'] as String?,
        customSpeechType: talk['custom_speech_type'] as String?,
        duration: talk['duration'] as int?,
      );
      _fetchTalks();
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<AuthProvider>(context, listen: false).language;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.tr('error', lang)}: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.completed;
      case 'processing':
        return AppColors.processing;
      case 'failed':
        return AppColors.failed;
      default:
        return AppColors.pending;
    }
  }

  int _countVersions(Map<String, dynamic> node) {
    int count = 1;
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        count += _countVersions(child as Map<String, dynamic>);
      }
    }
    return count;
  }

  String _buildMeta(Map<String, dynamic> talk, String lang) {
    final typeLabel = AppTranslations.translateSpeechType(talk['speech_type'], lang);
    final place = talk['place'] as String? ?? '';
    final duration = talk['duration'] ?? 0;
    final status = talk['status'] as String? ?? '';
    final minLabel = AppTranslations.tr('min', lang);
    final parts = <String>[
      if (typeLabel.isNotEmpty) typeLabel,
      if (place.isNotEmpty) place,
      '$duration $minLabel',
    ];
    switch (status) {
      case 'completed':
        parts.add('${_countVersions(talk)} ${AppTranslations.tr('version_suffix', lang)}');
        break;
      case 'processing':
        parts.add(AppTranslations.tr('status_generating', lang).toLowerCase());
        break;
      case 'pending':
        parts.add(AppTranslations.tr('in_queue', lang));
        break;
      case 'failed':
        parts.add(AppTranslations.tr('failed', lang));
        break;
    }
    return parts.join(' · ');
  }

  bool _matchesFilter(Map<String, dynamic> t) {
    final status = t['status'] as String? ?? '';
    final shared = t['room_id'] != null;
    switch (_filterKey) {
      case 'filter_ready':
        return status == 'completed';
      case 'filter_generating':
        return status == 'processing' || status == 'pending';
      case 'filter_shared':
        return shared;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
    final c = context.colors;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.acc));
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.dangerTx),
              const SizedBox(height: 16),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: GoogleFonts.schibstedGrotesk(color: c.tx2, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchTalks,
                icon: const Icon(Icons.refresh),
                label: Text(AppTranslations.tr('refresh', lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.acc,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_talks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.surf,
                shape: BoxShape.circle,
                border: Border.all(color: c.bord),
              ),
              child: Icon(Icons.mic_none_outlined, size: 56, color: c.accTx),
            ),
            const SizedBox(height: 20),
            Text(
              AppTranslations.tr('no_talks', lang),
              style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.tr('talks_subtitle', lang),
              style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: openCreateTalkDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppTranslations.tr('new_talk', lang)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.acc,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _talks.cast<Map<String, dynamic>>().where(_matchesFilter).where((t) {
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      final topic = (t['topic'] as String? ?? '').toLowerCase();
      final meta = _buildMeta(t, lang).toLowerCase();
      return topic.contains(q) || meta.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 20, 16, 32)
          : const EdgeInsets.fromLTRB(36, 30, 36, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    AppTranslations.tr('my_talks', lang),
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: c.tx,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.surf,
                        border: Border.all(color: c.bord),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 17, color: c.tx3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              style: GoogleFonts.schibstedGrotesk(fontSize: 13, color: c.tx),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: AppTranslations.tr('search', lang),
                                hintStyle: GoogleFonts.schibstedGrotesk(fontSize: 13, color: c.tx3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filterKeys.map((fKey) {
                  final active = _filterKey == fKey;
                  final label = AppTranslations.tr(fKey, lang);
                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() => _filterKey = fKey),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? c.acc : c.surf,
                        borderRadius: BorderRadius.circular(99),
                        border: active ? null : Border.all(color: c.bord),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? Colors.white : c.tx2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: c.surf,
                  border: Border.all(color: c.bordSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(36.0),
                        child: Center(
                          child: Text(
                            AppTranslations.tr('no_matching_talks', lang),
                            style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                          ),
                        ),
                      )
                    : Column(
                        children: filtered.map((talk) {
                          final id = talk['id'] as int;
                          final status = talk['status'] as String? ?? '';
                          final statusColor = _statusColor(status);
                          final topic = talk['topic'] as String? ?? AppTranslations.tr('new_talk', lang);
                          final isShared = talk['room_id'] != null;
                          final isFailed = status == 'failed';

                          return InkWell(
                            onTap: () {
                              NavigationPersistence.saveState(
                                tabIndex: 0,
                                detailType: 'talk',
                                detailId: id,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TalkDetailScreen(talkNode: talk)),
                              ).then((_) {
                                NavigationPersistence.saveState(tabIndex: 0);
                                _fetchTalks();
                              });
                            },
                            onLongPress: () => _deleteTalk(id, topic),
                            hoverColor: c.accSoft.withValues(alpha: 0.5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: c.bordSoft)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                      boxShadow: status == 'processing'
                                          ? [BoxShadow(color: statusColor, blurRadius: 8)]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          topic,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.schibstedGrotesk(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: c.tx,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _buildMeta(talk, lang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isShared) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.sharedBadgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppTranslations.tr('shared', lang),
                                        style: GoogleFonts.schibstedGrotesk(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.sharedBadgeTx,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isFailed) ...[
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () => _retryTalk(talk),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: c.tx2,
                                        side: BorderSide(color: c.bord),
                                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        minimumSize: Size.zero,
                                      ),
                                      child: Text(
                                        AppTranslations.tr('retry', lang),
                                        style: GoogleFonts.schibstedGrotesk(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 19, color: c.tx3),
                                    hoverColor: AppColors.dangerTx.withValues(alpha: 0.15),
                                    splashRadius: 20,
                                    tooltip: AppTranslations.tr('delete', lang),
                                    onPressed: () => _deleteTalk(id, topic),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.chevron_right, size: 18, color: c.tx3),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

