import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'create_talk_dialog.dart';
import 'talk_detail_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final int roomId;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  Map<String, dynamic>? _room;
  List<dynamic> _roomTalks = [];
  bool _isLoading = true;
  String _error = '';

  bool get _isWriter => _room?['role'] == 'writer';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final room = await ApiService.getRoom(widget.roomId);
      // The /talks tree already includes every talk shared into rooms the
      // user is a member of — filter down to this room's roots here rather
      // than adding a separate backend endpoint for the same data.
      final allTalks = await ApiService.getTalkRequests();
      final roomTalks = allTalks.where((t) => t is Map && t['room_id'] == widget.roomId).toList();
      if (mounted) {
        setState(() {
          _room = room;
          _roomTalks = roomTalks;
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

  Future<void> _invite() async {
    final c = context.colors;
    final emailController = TextEditingController();
    String role = 'writer';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: c.surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.bord),
          ),
          title: Text('Üye Davet Et', style: GoogleFonts.schibstedGrotesk(color: c.tx, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.schibstedGrotesk(color: c.tx),
                decoration: InputDecoration(
                  hintText: 'E-posta adresi',
                  hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3),
                  filled: true,
                  fillColor: c.surf2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Yazar'),
                      selected: role == 'writer',
                      onSelected: (_) => setDialogState(() => role = 'writer'),
                      selectedColor: c.acc,
                      labelStyle: TextStyle(color: role == 'writer' ? Colors.white : c.tx2),
                      backgroundColor: c.surf2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Görüntüleyici'),
                      selected: role == 'reader',
                      onSelected: (_) => setDialogState(() => role = 'reader'),
                      selectedColor: c.acc,
                      labelStyle: TextStyle(color: role == 'reader' ? Colors.white : c.tx2),
                      backgroundColor: c.surf2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: c.tx3)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'email': emailController.text.trim(), 'role': role}),
              style: ElevatedButton.styleFrom(backgroundColor: c.acc),
              child: const Text('Davet Et', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result['email'] == null || result['email']!.isEmpty) return;

    try {
      await ApiService.inviteRoomMember(roomId: widget.roomId, email: result['email']!, role: result['role']!);
      await _fetchAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openCreateTalk() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateTalkDialog',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => CreateTalkDialog(roomId: widget.roomId),
    ).then((_) => _fetchAll());
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: _isWriter
          ? FloatingActionButton.extended(
              onPressed: _openCreateTalk,
              backgroundColor: c.acc,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.add),
              label: Text('Yeni Konuşma', style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w700, fontSize: 13.5)),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.acc))
            : _error.isNotEmpty
                ? Center(child: Text(_error, style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx)))
                : RefreshIndicator(
                    onRefresh: _fetchAll,
                    color: c.acc,
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
                                  InkWell(
                                    onTap: () => Navigator.pop(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(Icons.arrow_back, size: 22, color: c.tx2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _room?['name'] as String? ?? 'Oda',
                                      style: GoogleFonts.schibstedGrotesk(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        color: c.tx,
                                      ),
                                    ),
                                  ),
                                  if (_isWriter)
                                    OutlinedButton.icon(
                                      onPressed: _invite,
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                                      label: Text('Davet Et', style: GoogleFonts.schibstedGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_room?['members'] as List<dynamic>? ?? []).map((m) {
                                  final map = m as Map<String, dynamic>;
                                  final role = map['role'] as String? ?? 'reader';
                                  final name = (map['nickname'] as String?)?.isNotEmpty == true
                                      ? map['nickname'] as String
                                      : map['email'] as String? ?? '';
                                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                                  return Container(
                                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                                    decoration: BoxDecoration(
                                      color: c.surf,
                                      border: Border.all(color: c.bordSoft),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: c.accSoft,
                                          child: Text(
                                            initial,
                                            style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: c.accTx),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(name, style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.tx)),
                                        const SizedBox(width: 6),
                                        Text(
                                          role == 'writer' ? 'Yazar' : 'Görüntüleyici',
                                          style: GoogleFonts.schibstedGrotesk(fontSize: 11, color: c.tx3),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Odadaki Konuşmalar',
                                style: GoogleFonts.schibstedGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: c.tx2),
                              ),
                              const SizedBox(height: 10),
                              if (_roomTalks.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: c.surf,
                                    border: Border.all(color: c.bordSoft),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _isWriter ? 'Bu odada henüz konuşma yok. Sağ alttaki butonla ekleyin.' : 'Bu odada henüz konuşma yok.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                                    ),
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
                                    children: _roomTalks.map((talk) {
                                      final map = talk as Map<String, dynamic>;
                                      final status = map['status'] as String? ?? '';
                                      final statusColor = status == 'completed'
                                          ? AppColors.completed
                                          : status == 'processing'
                                              ? AppColors.processing
                                              : status == 'failed'
                                                  ? AppColors.failed
                                                  : AppColors.pending;
                                      final duration = map['duration'] ?? 0;
                                      final meta = '$duration dk · ${_countVersions(map)} sürüm';
                                      return InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => TalkDetailScreen(talkNode: map)),
                                          ).then((_) => _fetchAll());
                                        },
                                        hoverColor: c.accSoft.withValues(alpha: 0.5),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.bordSoft))),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      map['topic'] as String? ?? 'Konuşma',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: c.tx),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(meta, style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx3)),
                                                  ],
                                                ),
                                              ),
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
                    ),
                  ),
      ),
    );
  }
}
