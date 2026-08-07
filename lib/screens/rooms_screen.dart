import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Text('Yeni Oda', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Oda adı (örn. Pazarlama Ekibi)',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Oluştur', style: TextStyle(color: Colors.white)),
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
    Provider.of<AuthProvider>(context); // rebuild on language/auth change

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Odalar', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _createRoom,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Yeni oda',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : _error.isNotEmpty
                ? Center(
                    child: Text(_error, style: GoogleFonts.inter(color: Colors.redAccent)),
                  )
                : _rooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_outlined, size: 56, color: Color(0xFF475569)),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz bir odanız yok',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ekip arkadaşlarınızla konuşma metinlerini birlikte yönetmek için bir oda oluşturun.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _createRoom,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Oda Oluştur'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRooms,
                        color: const Color(0xFF6366F1),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final role = room['role'] as String? ?? 'reader';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RoomDetailScreen(roomId: room['id'] as int),
                                      ),
                                    ).then((_) => _fetchRooms());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.groups_rounded, color: Color(0xFFA5B4FC)),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            room['name'] as String? ?? '',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: role == 'writer'
                                                ? const Color(0xFF059669).withValues(alpha: 0.2)
                                                : const Color(0xFF334155),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            role == 'writer' ? 'Yazar' : 'Görüntüleyici',
                                            style: GoogleFonts.inter(
                                              color: role == 'writer' ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
