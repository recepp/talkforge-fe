import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// A room's discussion thread for a specific talk version, plus the
/// "summarize into a new version" action (writer members only).
class DiscussionPanel extends StatefulWidget {
  const DiscussionPanel({
    super.key,
    required this.talkId,
    required this.roomId,
    this.onVersionGenerated,
  });

  final int talkId;
  final int roomId;

  /// Called after a new version has been queued from the discussion summary,
  /// so the parent screen can reload the version tree.
  final VoidCallback? onVersionGenerated;

  @override
  State<DiscussionPanel> createState() => _DiscussionPanelState();
}

class _DiscussionPanelState extends State<DiscussionPanel> {
  final _messageController = TextEditingController();
  List<dynamic> _messages = [];
  String? _role;
  String? _roomName;
  bool _isLoading = true;
  bool _isPosting = false;
  bool _isSummarizing = false;
  String _error = '';

  bool get _isWriter => _role == 'writer';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void didUpdateWidget(covariant DiscussionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.talkId != widget.talkId) {
      _fetchAll();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        ApiService.getTalkMessages(widget.talkId),
        ApiService.getRoom(widget.roomId),
      ]);
      if (mounted) {
        final room = results[1] as Map<String, dynamic>;
        setState(() {
          _messages = results[0] as List<dynamic>;
          _role = room['role'] as String?;
          _roomName = room['name'] as String?;
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);
    try {
      await ApiService.postTalkMessage(widget.talkId, text);
      _messageController.clear();
      final messages = await ApiService.getTalkMessages(widget.talkId);
      if (mounted) setState(() => _messages = messages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _summarize() async {
    if (_messages.isEmpty || _isSummarizing) return;

    setState(() => _isSummarizing = true);
    try {
      await ApiService.summarizeDiscussion(widget.talkId);
      widget.onVersionGenerated?.call();
      if (mounted) {
        final c = context.colors;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tartışma özetlendi, yeni versiyon üretiliyor.'),
            backgroundColor: c.acc,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.bordSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 18, color: c.accTx),
              const SizedBox(width: 8),
              Text(
                _roomName != null && _roomName!.isNotEmpty ? 'Tartışma · $_roomName' : 'Tartışma',
                style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: c.acc)))
          else if (_error.isNotEmpty)
            Text(_error, style: GoogleFonts.schibstedGrotesk(color: Colors.redAccent, fontSize: 12))
          else ...[
            if (_messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Henüz mesaj yok. Ekiple bu versiyon hakkında konuşmaya başlayın.',
                  style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 12),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index] as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.surf2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.bord),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m['nickname'] as String?)?.isNotEmpty == true ? m['nickname'] as String : 'Kullanıcı',
                                style: GoogleFonts.schibstedGrotesk(color: c.accTx, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m['text'] as String? ?? '',
                                style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13),
                    minLines: 1,
                    maxLines: 3,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Bir mesaj yazın...',
                      hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                      filled: true,
                      fillColor: c.surf2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isPosting ? null : _sendMessage,
                  icon: _isPosting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accTx))
                      : Icon(Icons.send_rounded, color: c.accTx),
                ),
              ],
            ),
            if (_isWriter) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_messages.isEmpty || _isSummarizing) ? null : _summarize,
                  icon: _isSummarizing
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.accTx))
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Tartışmayı Özetle ve Yeni Versiyon Üret'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accTx,
                    side: BorderSide(color: c.bord),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
