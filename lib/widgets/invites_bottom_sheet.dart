import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class InvitesBottomSheet extends StatefulWidget {
  const InvitesBottomSheet({super.key, this.onInvitesChanged});

  final VoidCallback? onInvitesChanged;

  static Future<void> show(BuildContext context, {VoidCallback? onInvitesChanged}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvitesBottomSheet(onInvitesChanged: onInvitesChanged),
    );
  }

  @override
  State<InvitesBottomSheet> createState() => _InvitesBottomSheetState();
}

class _InvitesBottomSheetState extends State<InvitesBottomSheet> {
  List<dynamic> _invites = [];
  bool _isLoading = true;
  String _error = '';
  final Set<int> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchInvites();
  }

  Future<void> _fetchInvites() async {
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
        if (mounted) {
          _showSnack(AppTranslations.tr('invite_accepted', lang), isSuccess: true);
        }
      } else {
        await ApiService.declineInvite(inviteId);
        if (mounted) {
          _showSnack(AppTranslations.tr('invite_declined', lang), isSuccess: false);
        }
      }
      await _fetchInvites();
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
    final lang = Provider.of<AuthProvider>(context).language;
    final c = context.colors;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.bord, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: c.bordSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.accSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.mail_outline_rounded, color: c.accTx, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr('pending_invites', lang),
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.tx,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (!_isLoading && _invites.isNotEmpty)
                        Text(
                          '${_invites.length} ${AppTranslations.tr('invites_badge', lang)}',
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 12,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.tx3, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: _buildContent(c, lang),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppColors c, String lang) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: c.acc, strokeWidth: 2.5)),
      );
    }

    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.dangerTx, size: 40),
            const SizedBox(height: 10),
            Text(_error, style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _fetchInvites,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(AppTranslations.tr('retry', lang), style: GoogleFonts.schibstedGrotesk()),
              style: OutlinedButton.styleFrom(foregroundColor: c.accTx, side: BorderSide(color: c.bord)),
            ),
          ],
        ),
      );
    }

    if (_invites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: c.accSoft, shape: BoxShape.circle),
              child: Icon(Icons.mark_email_read_outlined, size: 30, color: c.accTx),
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.tr('no_invites', lang),
              style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: c.tx),
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.tr('no_invites_sub', lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, color: c.tx3),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _invites.map((invite) {
        final id = invite['id'] as int;
        final roomName = invite['room_name'] as String? ?? '';
        final invitedBy = invite['invited_by'] as String? ?? '';
        final role = invite['role'] as String? ?? 'reader';
        final isLoading = _loadingIds.contains(id);
        final isWriter = role == 'writer';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surf2,
            border: Border.all(color: c.bordSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.groups_rounded, color: c.accTx, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: GoogleFonts.schibstedGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.tx,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (invitedBy.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${AppTranslations.tr('invited_by', lang)} $invitedBy',
                              style: GoogleFonts.schibstedGrotesk(
                                fontSize: 12,
                                color: c.tx3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isWriter ? AppColors.sharedBadgeBg : c.surf,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: isWriter ? AppColors.sharedBadgeTx.withValues(alpha: 0.3) : c.bordSoft),
                    ),
                    child: Text(
                      isWriter ? AppTranslations.tr('writer', lang) : AppTranslations.tr('reader', lang),
                      style: GoogleFonts.schibstedGrotesk(
                        fontSize: 10.5,
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
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.acc),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respondInvite(id, true),
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: Text(
                          AppTranslations.tr('accept', lang),
                          style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _respondInvite(id, false),
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: Text(
                          AppTranslations.tr('decline', lang),
                          style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerTx,
                          side: BorderSide(color: AppColors.dangerBord),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
