import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../widgets/talk_diff_view.dart';

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
  Timer? _pollTimer;

  bool _isReloading = false;
  bool _isSubmitting = false;
  bool _viewDiff = false;
  String _errorMessage = '';

  List<String> _getQuickSuggestions(String lang) {
    return [
      AppTranslations.tr('quick_more_enthusiastic', lang),
      AppTranslations.tr('quick_more_formal', lang),
      AppTranslations.tr('quick_summarize', lang),
      AppTranslations.tr('quick_shorten_duration', lang),
      AppTranslations.tr('quick_strengthen_intro', lang),
    ];
  }

  @override
  void initState() {
    super.initState();
    _talkTree = widget.talkNode;
    _selectedNode = _getLatestNode(widget.talkNode);
    _reloadData();
  }

  Map<String, dynamic> _getLatestNode(Map<String, dynamic> root) {
    final flatList = _flattenTree(root, 0);
    if (flatList.isEmpty) return root;

    Map<String, dynamic> latest = flatList.first.node;
    for (final flat in flatList) {
      final node = flat.node;
      final int currentId = (node['id'] as num?)?.toInt() ?? 0;
      final int latestId = (latest['id'] as num?)?.toInt() ?? 0;
      if (currentId > latestId) {
        latest = node;
      }
    }
    return latest;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _instructionController.dispose();
    super.dispose();
  }

  bool _treeHasPendingOrProcessing(Map<String, dynamic> node) {
    final status = node['status'] as String? ?? '';
    if (status == 'pending' || status == 'processing') {
      return true;
    }
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        if (_treeHasPendingOrProcessing(child as Map<String, dynamic>)) {
          return true;
        }
      }
    }
    return false;
  }

  void _checkAndManagePolling() {
    if (_treeHasPendingOrProcessing(_talkTree)) {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
        _reloadData(silent: true);
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _reloadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isReloading = true;
        _errorMessage = '';
      });
    }
    try {
      final talks = await ApiService.getTalkRequests();
      Map<String, dynamic>? freshRoot;
      final currentSubtreeIds = _flattenTree(_talkTree, 0).map((n) => n.node['id'] as int).toSet();

      for (final t in talks) {
        if (t != null) {
          final tMap = t as Map<String, dynamic>;
          final tNodeIds = _flattenTree(tMap, 0).map((n) => n.node['id'] as int).toSet();
          if (tNodeIds.intersection(currentSubtreeIds).isNotEmpty) {
            freshRoot = tMap;
            break;
          }
        }
      }

      if (mounted) {
        if (freshRoot != null) {
          final currentSelectedId = _selectedNode?['id'] as int?;
          setState(() {
            _talkTree = freshRoot!;
            if (currentSelectedId != null) {
              _selectedNode = _findNodeInTree(freshRoot, currentSelectedId) ?? _getLatestNode(freshRoot);
            } else {
              _selectedNode = _getLatestNode(freshRoot);
            }
          });
          _checkAndManagePolling();
        } else if (!silent) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isReloading = false;
        });
      }
    }
  }

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

  /// Returns the stable version number stored in the backend for this node.
  int _getVersionNumber(Map<String, dynamic> node) {
    return (node['version_number'] as num?)?.toInt() ?? 1;
  }

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
        _viewDiff = false;
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

  Future<void> _deleteVersionNode(Map<String, dynamic> node) async {
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    final flatNodes = _flattenTree(_talkTree, 0);

    if (flatNodes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.tr('cannot_delete_only_version', lang)),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nodeId = node['id'] as int;
    final isRoot = node['parent_id'] == null || nodeId == _talkTree['id'];
    final versionNum = _getVersionNumber(node);

    final titleText = isRoot
        ? '${AppTranslations.tr('delete_version', lang)} (Root)'
        : '${AppTranslations.tr('delete_version', lang)} (#$versionNum)';
    final contentText = AppTranslations.tr('confirm_delete_version', lang);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              titleText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          contentText,
          style: GoogleFonts.inter(
            color: const Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppTranslations.tr('cancel', lang),
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(
              AppTranslations.tr('delete', lang),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
        await ApiService.deleteTalkRequest(nodeId);
        if (!mounted) return;

        final selectedId = _selectedNode?['id'] as int?;
        if (selectedId == nodeId) {
          final parentId = node['parent_id'] as int?;
          if (parentId != null) {
            _selectedNode = _findNodeInTree(_talkTree, parentId);
          } else {
            _selectedNode = null;
          }
        }
        await _reloadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppTranslations.tr('error', lang)}: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCurrentTalk() async {
    await _deleteVersionNode(_talkTree);
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

  String _getStatusText(String status, String lang) {
    switch (status) {
      case 'completed':
        return AppTranslations.tr('status_completed', lang);
      case 'processing':
        return AppTranslations.tr('status_generating', lang);
      case 'failed':
        return AppTranslations.tr('status_failed', lang);
      default:
        return AppTranslations.tr('status_pending', lang);
    }
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  void _copyToClipboard(String text, String lang) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              AppTranslations.tr('speech_copied', lang),
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
    final flatNodes = _flattenTree(_talkTree, 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161E2E),
        elevation: 0,
        title: Text(
          AppTranslations.tr('versions', lang),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
              ),
            )
          else
            IconButton(
              onPressed: _reloadData,
              tooltip: AppTranslations.tr('refresh', lang),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 850;
                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 380,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildHeroHeaderCard(lang),
                                  const SizedBox(height: 16),
                                  _buildTreeSection(flatNodes, lang),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildActiveNodeWorkspace(lang),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroHeaderCard(lang),
                          const SizedBox(height: 16),
                          _buildTreeSection(flatNodes, lang),
                          const SizedBox(height: 20),
                          _buildActiveNodeWorkspace(lang),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeaderCard(String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3730A3).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                ),
                child: Text(
                  AppTranslations.translateSpeechType(_talkTree['speech_type'], lang),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA5B4FC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _talkTree['topic'] ?? '',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaBadge(Icons.location_on_outlined, _talkTree['place'] ?? ''),
              _buildMetaBadge(Icons.timer_outlined, '${_talkTree['duration'] ?? 0} ${AppTranslations.tr('minutes', lang)}'),
              _buildMetaBadge(Icons.language_outlined, AppTranslations.translateLanguageName(_talkTree['language'], lang)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSection(List<FlatTreeNode> flatNodes, String lang) {
    return Container(
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
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.tr('versions', lang),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${flatNodes.length} ${AppTranslations.tr('versions', lang)}',
                  style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: flatNodes.map((flat) {
              final node = flat.node;
              final status = node['status'] as String;
              final statusColor = _getStatusColor(status);
              final isSelected = _selectedNode != null && _selectedNode!['id'] == node['id'];
              final isRoot = node['parent_id'] == null;
              final indent = (flat.depth * 14.0).clamp(0.0, 42.0);

              return Padding(
                padding: EdgeInsets.only(left: indent, bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedNode = node;
                      _viewDiff = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF312E81) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF1E293B),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            isRoot ? Icons.adjust : Icons.subdirectory_arrow_right_rounded,
                            size: 16,
                            color: isSelected ? const Color(0xFFA5B4FC) : const Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                            isRoot
                                    ? '${AppTranslations.tr("version", lang)} #${_getVersionNumber(node)} (Root)'
                                    : '${AppTranslations.tr("version", lang)} #${_getVersionNumber(node)}',
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              if (!isRoot && node['instruction'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '"${node['instruction']}"',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _getStatusText(status, lang),
                              style: GoogleFonts.inter(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (flatNodes.length > 1) ...[
                              const SizedBox(height: 6),
                              Tooltip(
                                message: AppTranslations.tr('delete_version', lang),
                                child: InkWell(
                                  onTap: () => _deleteVersionNode(node),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: isSelected ? const Color(0xFFFCA5A5) : const Color(0xFFF87171).withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNodeWorkspace(String lang) {
    if (_selectedNode == null) return const SizedBox.shrink();

    final parentId = _selectedNode!['parent_id'];
    final parentNode = parentId != null ? _findNodeInTree(_talkTree, parentId as int) : null;
    final isCompleted = _selectedNode!['status'] == 'completed';
    final text = _selectedNode!['generated_text'] ?? '';
    final wordCount = _countWords(text);
    final readTimeMinutes = (wordCount / 130).ceil();
    final suggestions = _getQuickSuggestions(lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          () {
                            final isRootNode = _selectedNode!['parent_id'] == null;
                            final vNum = _getVersionNumber(_selectedNode!);
                            if (isRootNode) {
                              return '${AppTranslations.tr("version", lang)} #$vNum (Root)';
                            }
                            return '${AppTranslations.tr("version", lang)} #$vNum';
                          }(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedNode!['instruction'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"${_selectedNode!['instruction']}"',
                            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCompleted && text.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(text, lang),
                      icon: const Icon(Icons.copy, size: 14),
                      label: Text(AppTranslations.tr('copy_speech', lang)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA5B4FC),
                        side: const BorderSide(color: Color(0xFF4338CA)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
              if (isCompleted) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF243044), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (parentNode != null)
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(AppTranslations.tr('view_full_text', lang)),
                            selected: !_viewDiff,
                            onSelected: (_) => setState(() => _viewDiff = false),
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: GoogleFonts.inter(
                              color: !_viewDiff ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(AppTranslations.tr('view_diff', lang)),
                            selected: _viewDiff,
                            onSelected: (_) => setState(() => _viewDiff = true),
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: GoogleFonts.inter(
                              color: _viewDiff ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (!_viewDiff && text.isNotEmpty)
                      Text(
                        '$wordCount ${AppTranslations.tr("words", lang)} • ~$readTimeMinutes ${AppTranslations.tr("minutes", lang)}',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_viewDiff && parentNode != null && isCompleted)
          TalkDiffView(
            parentText: parentNode['generated_text'] ?? '',
            childText: text,
            parentId: _getVersionNumber(parentNode),
            childId: _getVersionNumber(_selectedNode!),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(minHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF243044)),
            ),
            child: _selectedNode!['status'] == 'pending' || _selectedNode!['status'] == 'processing'
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF818CF8)),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.tr('status_generating', lang),
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : SelectableText(
                    text,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.65,
                    ),
                  ),
          ),
        const SizedBox(height: 16),
        if (isCompleted)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF243044)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    Text(
                      AppTranslations.tr('update_instruction', lang),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions.map((suggestion) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(suggestion),
                          onPressed: () {
                            setState(() {
                              _instructionController.text = suggestion;
                            });
                          },
                          backgroundColor: const Color(0xFF0F172A),
                          labelStyle: GoogleFonts.inter(
                            color: const Color(0xFFC7D2FE),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _instructionController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: AppTranslations.tr('update_instruction_hint', lang),
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF243044)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _isSubmitting
                            ? AppTranslations.tr('status_generating', lang)
                            : AppTranslations.tr('apply_changes', lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
