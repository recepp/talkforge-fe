import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchTalks();
  }

  Future<void> _fetchTalks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final talks = await ApiService.getTalkRequests();
      setState(() {
        _talks = talks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Konuşma Hazırlıklarım',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchTalks,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
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
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchTalks,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                          ),
                          child: const Text('Tekrar Dene'),
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
                          const Icon(
                            Icons.mic_none_outlined,
                            size: 72,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz bir konuşma hazırlığı yapmadınız.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateTalkScreen(),
                                ),
                              );
                              if (result == true) {
                                _fetchTalks();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Yeni Konuşma Başlat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _talks.length,
                      itemBuilder: (context, index) {
                        final talk = _talks[index];
                        final status = talk['status'] as String;
                        final statusColor = _getStatusColor(status);

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF334155), width: 1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TalkDetailScreen(talkNode: talk),
                                ),
                              ).then((_) => _fetchTalks());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Speech Type Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF312E81),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          talk['speech_type'] ?? 'Genel Konuşma',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFC7D2FE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Status Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Topic Title
                                  Text(
                                    talk['topic'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Place & Duration Info row
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        talk['place'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${talk['duration'] ?? 0} dk',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.language_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        talk['language'] ?? 'Türkçe',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTalkScreen(),
            ),
          );
          if (result == true) {
            _fetchTalks();
          }
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Yeni Konuşma',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
