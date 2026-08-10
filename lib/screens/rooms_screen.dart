import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
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
      await _fetchRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
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
                      final membersLabel = AppTranslations.tr('members', lang);
                      final talksLabel = AppTranslations.tr('talks', lang);
                      final roleText = isWriter ? AppTranslations.tr('writer', lang) : AppTranslations.tr('reader', lang);
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RoomDetailScreen(roomId: room['id'] as int)),
                          ).then((_) => _fetchRooms());
                        },
                        hoverColor: c.accSoft.withValues(alpha: 0.5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.bordSoft))),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.groups_rounded, color: c.accTx, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room['name'] as String? ?? '',
                                      style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: c.tx),
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
                              const SizedBox(width: 8),
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

