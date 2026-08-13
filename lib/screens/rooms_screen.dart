import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'room_detail_screen.dart';
import '../services/navigation_persistence.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => RoomsScreenState();
}

class RoomsScreenState extends State<RoomsScreen> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  Future<void> fetchRooms({bool showLoading = true}) async {
    if (showLoading || _rooms.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final rooms = await ApiService.getRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
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

  Future<void> _createRoom() async {
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    if (_rooms.length >= 3) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: const Text('En fazla 3 odada yer alabilirsiniz. Oda limitinize ulaştınız.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final c = context.colors;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.bord),
        ),
        title: Text(AppTranslations.tr('new_room', lang), style: GoogleFonts.schibstedGrotesk(color: c.tx, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.schibstedGrotesk(color: c.tx),
          decoration: InputDecoration(
            hintText: AppTranslations.tr('room_name_hint', lang),
            hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3),
            filled: true,
            fillColor: c.surf2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.tr('cancel', lang), style: GoogleFonts.schibstedGrotesk(color: c.tx3)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: c.acc),
            child: Text(AppTranslations.tr('create', lang), style: GoogleFonts.schibstedGrotesk(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      await ApiService.createRoom(name.trim());
      await fetchRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    }
  }

  Future<void> _leaveRoom(int roomId, String roomName) async {
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
          AppTranslations.tr('leave_room', lang),
          style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.bold, color: c.tx),
        ),
        content: Text(
          roomName.isNotEmpty
              ? '${AppTranslations.tr('confirm_leave_room', lang)}\n($roomName)'
              : AppTranslations.tr('confirm_leave_room', lang),
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
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              AppTranslations.tr('leave_room', lang),
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
        await ApiService.leaveRoom(roomId);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
              duration: const Duration(milliseconds: 2000),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.tr('leave_room_success', lang),
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
        await fetchRooms();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
              duration: const Duration(milliseconds: 3000),
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context); // rebuild on language/auth change
    final lang = authProvider.language;
    final c = context.colors;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.acc));
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx)));
    }

    return RefreshIndicator(
      color: c.acc,
      onRefresh: fetchRooms,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: isMobile
            ? const EdgeInsets.fromLTRB(16, 20, 16, 32)
            : const EdgeInsets.fromLTRB(36, 30, 36, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppTranslations.tr('rooms', lang),
                      style: GoogleFonts.schibstedGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: c.tx,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: fetchRooms,
                      icon: Icon(Icons.refresh_rounded, color: c.tx3, size: 20),
                      tooltip: AppTranslations.tr('refresh', lang),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _createRoom,
                      icon: const Icon(Icons.add, size: 17),
                      label: Text(AppTranslations.tr('new_room', lang), style: GoogleFonts.schibstedGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.accTx,
                        side: BorderSide(color: c.bord),
                        backgroundColor: c.surf,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_rooms.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: c.surf,
                      border: Border.all(color: c.bordSoft),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.groups_outlined, size: 48, color: c.tx3),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.tr('no_rooms_yet', lang),
                          style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.tr('no_rooms_sub', lang),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: c.surf,
                      border: Border.all(color: c.bordSoft),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: _rooms.map((room) {
                        final role = room['role'] as String? ?? 'reader';
                        final isWriter = role == 'writer';
                        final memberCount = room['member_count'] ?? 0;
                        final talkCount = room['talk_count'] ?? 0;
                        final hasUnread = room['has_unread'] == true || (room['unread_count'] ?? 0) > 0;
                        final unreadCount = room['unread_count'] ?? 0;
                        final membersLabel = AppTranslations.tr('members', lang);
                        final talksLabel = AppTranslations.tr('talks', lang);
                        final roleText = isWriter ? AppTranslations.tr('writer', lang) : AppTranslations.tr('reader', lang);
                        return InkWell(
                          onTap: () {
                            final roomId = room['id'] as int;
                            NavigationPersistence.saveState(
                              tabIndex: 1,
                              detailType: 'room',
                              detailId: roomId,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RoomDetailScreen(roomId: roomId)),
                            ).then((_) {
                              NavigationPersistence.saveState(tabIndex: 1);
                              fetchRooms();
                            });
                          },
                        hoverColor: c.accSoft.withValues(alpha: 0.5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.bordSoft))),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.groups_rounded, color: c.accTx, size: 20),
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      top: -3,
                                      right: -3,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: c.surf, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            room['name'] as String? ?? '',
                                            style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: c.tx),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (hasUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0x22EF4444),
                                              borderRadius: BorderRadius.circular(99),
                                              border: Border.all(color: const Color(0x66EF4444)),
                                            ),
                                            child: Text(
                                              unreadCount > 0 ? '$unreadCount yeni' : 'Yeni',
                                              style: GoogleFonts.schibstedGrotesk(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$memberCount $membersLabel · $talkCount $talksLabel',
                                      style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx3),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isWriter ? AppColors.sharedBadgeBg : c.surf2,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  roleText,
                                  style: GoogleFonts.schibstedGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isWriter ? c.roleWriterTx : c.tx2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, size: 18, color: c.tx3),
                                color: c.surf,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: c.bordSoft),
                                ),
                                onSelected: (val) {
                                  if (val == 'leave') {
                                    _leaveRoom(room['id'] as int, room['name'] as String? ?? '');
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'leave',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.logout_rounded, size: 16, color: AppColors.dangerTx),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppTranslations.tr('leave_room', lang),
                                          style: GoogleFonts.schibstedGrotesk(fontSize: 13, color: AppColors.dangerTx, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
    ),
  );
}
}

