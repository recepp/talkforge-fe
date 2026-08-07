import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
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
    final emailController = TextEditingController();
    String role = 'writer';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          title: Text('Üye Davet Et', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'E-posta adresi',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
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
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(color: role == 'writer' ? Colors.white : const Color(0xFF94A3B8)),
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Görüntüleyici'),
                      selected: role == 'reader',
                      onSelected: (_) => setDialogState(() => role = 'reader'),
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(color: role == 'reader' ? Colors.white : const Color(0xFF94A3B8)),
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'email': emailController.text.trim(), 'role': role}),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(_room?['name'] as String? ?? 'Oda', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: _isWriter
          ? FloatingActionButton.extended(
              onPressed: _openCreateTalk,
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Yeni Konuşma', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : _error.isNotEmpty
                ? Center(child: Text(_error, style: GoogleFonts.inter(color: Colors.redAccent)))
                : RefreshIndicator(
                    onRefresh: _fetchAll,
                    color: const Color(0xFF6366F1),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161E2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF243044)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Üyeler',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (_isWriter)
                                    TextButton.icon(
                                      onPressed: _invite,
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                      label: const Text('Davet Et'),
                                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFA5B4FC)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...(_room?['members'] as List<dynamic>? ?? []).map((m) {
                                final map = m as Map<String, dynamic>;
                                final role = map['role'] as String? ?? 'reader';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_circle, size: 20, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (map['nickname'] as String?)?.isNotEmpty == true
                                              ? map['nickname'] as String
                                              : map['email'] as String? ?? '',
                                          style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        role == 'writer' ? 'Yazar' : 'Görüntüleyici',
                                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Konuşmalar',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        if (_roomTalks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                _isWriter
                                    ? 'Bu odada henüz konuşma yok. Sağ alttaki butonla ekleyin.'
                                    : 'Bu odada henüz konuşma yok.',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ..._roomTalks.map((talk) {
                            final map = talk as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => TalkDetailScreen(talkNode: map)),
                                    ).then((_) => _fetchAll());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Text(
                                      map['topic'] as String? ?? 'Konuşma',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}
