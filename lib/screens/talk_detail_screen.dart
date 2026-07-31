import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class FlatTreeNode {
  final Map<String, dynamic> node;
  final int depth;
  FlatTreeNode(this.node, this.depth);
}

class TalkDetailScreen extends StatefulWidget {
  final Map<String, dynamic> talkNode;

  const TalkDetailScreen({super.key, required this.talkNode});

  @override
  State<TalkDetailScreen> createState() => _TalkDetailScreenState();
}

class _TalkDetailScreenState extends State<TalkDetailScreen> {
  late Map<String, dynamic> _talkTree;
  Map<String, dynamic>? _selectedNode;
  final _instructionController = TextEditingController();

  bool _isReloading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _talkTree = widget.talkNode;
    _reloadData();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  // Refetches talks to update the tree structure in memory
  Future<void> _reloadData() async {
    setState(() {
      _isReloading = true;
      _errorMessage = '';
    });
    try {
      final talks = await ApiService.getTalkRequests();
      final freshRoot = talks.firstWhere(
        (t) => t['id'] == _talkTree['id'],
        orElse: () => null,
      );

      if (freshRoot != null) {
        setState(() {
          _talkTree = freshRoot;
          if (_selectedNode != null) {
            // Update the selected node reference with updated database info
            _selectedNode = _findNodeInTree(freshRoot, _selectedNode!['id']) ?? freshRoot;
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Yenilenirken hata oluştu: $e';
      });
    } finally {
      setState(() {
        _isReloading = false;
      });
    }
  }

  // Recursive search to locate active node inside tree structure
  Map<String, dynamic>? _findNodeInTree(Map<String, dynamic> node, int id) {
    if (node['id'] == id) return node;
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        final found = _findNodeInTree(child as Map<String, dynamic>, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  // Flatten the recursive parent-child tree structure into a flat list for linear rendering
  List<FlatTreeNode> _flattenTree(Map<String, dynamic> root, int depth) {
    List<FlatTreeNode> list = [FlatTreeNode(root, depth)];
    final children = root['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        list.addAll(_flattenTree(child as Map<String, dynamic>, depth + 1));
      }
    }
    return list;
  }

  // Submit update rewrite instruction
  Future<void> _submitUpdate() async {
    if (_selectedNode == null) return;
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final newRequest = await ApiService.createTalkRequest(
        mode: 'update',
        parentId: _selectedNode!['id'],
        instruction: instruction,
      );
      _instructionController.clear();
      setState(() {
        _selectedNode = newRequest;
      });
      await _reloadData();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'processing':
        return const Color(0xFF3B82F6);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Tamamlandı';
      case 'processing':
        return 'Hazırlanıyor';
      case 'failed':
        return 'Hata';
      default:
        return 'Bekliyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatNodes = _flattenTree(_talkTree, 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Konuşma Dalları ve Sürümleri',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isReloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              onPressed: _reloadData,
              icon: const Icon(Icons.refresh, color: Colors.white),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Speech Info Header Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _talkTree['speech_type'] ?? 'Genel Hitabet',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF818CF8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Konu: ${_talkTree['topic'] ?? ""}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ortam: ${_talkTree['place'] ?? ""} • Süre: ${_talkTree['duration'] ?? 0} dk • Dil: ${_talkTree['language'] ?? "Türkçe"}',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tree Section Title
            Text(
              'Sürüm Dallanma Ağacı',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'İçeriğini incelemek ve güncellemek istediğiniz sürüme tıklayın.',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            // Indented Tree Node List
            Column(
              children: flatNodes.map((flat) {
                final node = flat.node;
                final status = node['status'] as String;
                final statusColor = _getStatusColor(status);
                final isSelected = _selectedNode != null && _selectedNode!['id'] == node['id'];
                final isRoot = node['parent_id'] == null;

                return Padding(
                  padding: EdgeInsets.only(
                    left: flat.depth * 24.0,
                    bottom: 8.0,
                  ),
                  child: Card(
                    color: isSelected ? const Color(0xFF312E81) : const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedNode = node;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Tree Icon
                            Icon(
                              isRoot
                                  ? Icons.radio_button_checked
                                  : Icons.subdirectory_arrow_right_outlined,
                              size: 18,
                              color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            // Version Info Label
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRoot
                                        ? 'Başlangıç Sürümü (#${node['id']})'
                                        : 'Düzeltme (#${node['id']})',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!isRoot) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Talimat: "${node['instruction'] ?? ''}"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFF1E293B), thickness: 1.5),
            const SizedBox(height: 16),

            // Detail Panel: Only displayed once a node is clicked
            if (_selectedNode == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_upward, size: 36, color: Color(0xFF475569)),
                      const SizedBox(height: 8),
                      Text(
                        'Konuşma metnini okumak ve güncelleme talimatı\ngöndermek için yukarıdaki dallardan bir sürüm seçin.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Header for active node detail panel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seçili Sürüm (#${_selectedNode!['id']}) İçeriği',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedNode = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Kapat'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Generated Text display container
              Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(minHeight: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: _selectedNode!['status'] == 'pending' ||
                        _selectedNode!['status'] == 'processing'
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF6366F1)),
                            const SizedBox(height: 16),
                            Text(
                              _selectedNode!['status'] == 'processing'
                                  ? 'AI konuşma metninizi yazıyor...'
                                  : 'Metin sıraya alındı, hazırlanıyor...',
                              style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : _selectedNode!['status'] == 'failed'
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'Metin oluşturulurken hata oluştu:\n${_selectedNode!['error_message'] ?? ""}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : SelectableText(
                            _selectedNode!['generated_text'] ?? 'Henüz metin üretilmemiş.',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
              ),
              const SizedBox(height: 24),

              // Refinement form (displayed only for completed nodes)
              if (_selectedNode!['status'] == 'completed') ...[
                Text(
                  'Bu Sürümü Düzelt / Güncelleştir',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _instructionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Örn: Dili daha coşkulu yap, süresini biraz kısalt...',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ]
          ],
        ),
      ),
    );
  }
}
