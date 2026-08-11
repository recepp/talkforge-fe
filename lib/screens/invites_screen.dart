import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key, this.onInvitesChanged});

  final VoidCallback? onInvitesChanged;

  @override
  State<InvitesScreen> createState() => InvitesScreenState();
}

class InvitesScreenState extends State<InvitesScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _invites = [];
  bool _isLoading = true;
  String _error = '';
  final Set<int> _loadingIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchInvites();
  }

  Future<void> fetchInvites() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final invites = await ApiService.getInvites();
      if (mounted) {
        setState(() {
          _invites = invites;
          _isLoading = false;
        });
        widget.onInvitesChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondInvite(int inviteId, bool accept) async {
    setState(() => _loadingIds.add(inviteId));
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    try {
      if (accept) {
        await ApiService.acceptInvite(inviteId);
        widget.onInvitesChanged?.call();
        if (mounted) {
          _showSnack(AppTranslations.tr('invite_accepted', lang), isSuccess: true);
        }
      } else {
        await ApiService.declineInvite(inviteId);
        widget.onInvitesChanged?.call();
        if (mounted) {
          _showSnack(AppTranslations.tr('invite_declined', lang), isSuccess: false);
        }
      }
      await fetchInvites();
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(inviteId));
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.schibstedGrotesk(color: Colors.white, fontSize: 13.5))),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Provider.of<AuthProvider>(context).language;
    final c = context.colors;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return RefreshIndicator(
      color: c.acc,
      onRefresh: fetchInvites,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: isMobile
            ? const EdgeInsets.fromLTRB(16, 20, 16, 32)
            : const EdgeInsets.fromLTRB(36, 30, 36, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.acc.withValues(alpha: 0.85), c.acc],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: c.acc.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr('invites', lang),
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: c.tx,
                          ),
                        ),
                        if (!_isLoading && _invites.isNotEmpty)
                          Text(
                            '${_invites.length} ${AppTranslations.tr('invites_badge', lang)}',
                            style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: AppColors.pending),
                          ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: fetchInvites,
                      icon: Icon(Icons.refresh_rounded, color: c.tx3, size: 20),
                      tooltip: AppTranslations.tr('refresh', lang),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── Loading skeleton ────────────────────────────────────────
                if (_isLoading)
                  _BuildSkeleton(c: c)

                // ── Error state ─────────────────────────────────────────────
                else if (_error.isNotEmpty)
                  _BuildError(error: _error, c: c, onRetry: fetchInvites, lang: lang)

                // ── Empty state ─────────────────────────────────────────────
                else if (_invites.isEmpty)
                  _BuildEmpty(c: c, lang: lang)

                // ── Invite list ─────────────────────────────────────────────
                else
                  _BuildInviteList(
                    invites: _invites,
                    loadingIds: _loadingIds,
                    onRespond: _respondInvite,
                    lang: lang,
                    c: c,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton Loader ────────────────────────────────────────────────────────────
class _BuildSkeleton extends StatelessWidget {
  const _BuildSkeleton({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: c.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.bordSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 180, height: 14, decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 10),
                Container(width: 120, height: 11, decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 14),
                Row(children: [
                  Container(width: 80, height: 30, decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 8),
                  Container(width: 80, height: 30, decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(8))),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────
class _BuildError extends StatelessWidget {
  const _BuildError({required this.error, required this.c, required this.onRetry, required this.lang});
  final String error;
  final AppColors c;
  final VoidCallback onRetry;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.dangerTx),
          const SizedBox(height: 14),
          Text(error, style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(AppTranslations.tr('retry', lang), style: GoogleFonts.schibstedGrotesk()),
            style: OutlinedButton.styleFrom(foregroundColor: c.accTx, side: BorderSide(color: c.bord)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _BuildEmpty extends StatelessWidget {
  const _BuildEmpty({required this.c, required this.lang});
  final AppColors c;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: c.surf,
        border: Border.all(color: c.bordSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.accSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mail_outline_rounded, size: 34, color: c.accTx),
          ),
          const SizedBox(height: 18),
          Text(
            AppTranslations.tr('no_invites', lang),
            style: GoogleFonts.schibstedGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.tx,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.tr('no_invites_sub', lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.schibstedGrotesk(fontSize: 13, color: c.tx3),
          ),
        ],
      ),
    );
  }
}

// ── Invite list ────────────────────────────────────────────────────────────────
class _BuildInviteList extends StatelessWidget {
  const _BuildInviteList({
    required this.invites,
    required this.loadingIds,
    required this.onRespond,
    required this.lang,
    required this.c,
  });

  final List<dynamic> invites;
  final Set<int> loadingIds;
  final void Function(int id, bool accept) onRespond;
  final String lang;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: invites.map<Widget>((invite) {
        final id = invite['id'] as int;
        final roomName = invite['room_name'] as String? ?? '';
        final invitedBy = invite['invited_by'] as String? ?? '';
        final role = invite['role'] as String? ?? 'reader';
        final isLoading = loadingIds.contains(id);
        final isWriter = role == 'writer';

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (ctx, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(0, 24 * (1 - value)), child: child),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: c.surf,
              border: Border.all(color: c.bord),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: c.acc.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Room icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.accSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(Icons.groups_rounded, color: c.accTx, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invitedBy.isNotEmpty
                                  ? '${AppTranslations.tr('invited_by', lang)} $invitedBy'
                                  : AppTranslations.tr('invite_from_room', lang),
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: c.tx3,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roomName,
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: c.tx,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWriter ? AppColors.sharedBadgeBg : c.surf2,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isWriter
                                ? AppColors.sharedBadgeTx.withValues(alpha: 0.3)
                                : c.bordSoft,
                          ),
                        ),
                        child: Text(
                          isWriter
                              ? AppTranslations.tr('writer', lang)
                              : AppTranslations.tr('reader', lang),
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isWriter ? c.roleWriterTx : c.tx2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    Center(
                      child: SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: c.acc),
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Accept button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onRespond(id, true),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              AppTranslations.tr('accept', lang),
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Decline button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onRespond(id, false),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: Text(
                              AppTranslations.tr('decline', lang),
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dangerTx,
                              side: BorderSide(color: AppColors.dangerBord),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
