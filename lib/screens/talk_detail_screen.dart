import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/talk_diff_view.dart';
import '../widgets/text_selection_toolbar.dart';
import '../widgets/share_buttons.dart';
import '../widgets/discussion_panel.dart';

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

  // Text selection toolbar
  final _toolbarController = TextSelectionToolbarController();
  final _textContainerKey = GlobalKey();
  String _currentSelectedText = '';
  String _pendingSelectedText = '';
  TextSelection? _currentTextSelection;
  Timer? _selectionDebounce;
  bool _isPartialSubmitting = false;
  bool _isTranslating = false;
  // Ephemeral translation preview of the selected node — never persisted,
  // never affects the version tree or what edits are based on.
  String? _translatedLanguage;
  String? _translatedText;
  bool _viewingTranslation = false;

  bool _isReloading = false;
  bool _isSubmitting = false;
  bool _viewDiff = false;
  bool _isVersionHistoryExpanded = false;
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
    _checkAndReapplyTranslation();
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
    _selectionDebounce?.cancel();
    _instructionController.dispose();
    _toolbarController.dispose();
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
          _checkAndReapplyTranslation();
        } else if (!silent) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
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

  String _getVersionLabel(Map<String, dynamic> node) {
    final label = node['version_label'] as String?;
    if (label != null && label.toString().isNotEmpty) {
      return label.toString();
    }
    final versionNum = (node['version_number'] as num?)?.toInt();
    if (versionNum != null) {
      return '$versionNum';
    }
    return '1';
  }

  void _selectNode(Map<String, dynamic> node) {
    setState(() {
      _selectedNode = node;
      _viewDiff = false;
      _translatedLanguage = null;
      _translatedText = null;
      _viewingTranslation = false;
    });
    _checkAndReapplyTranslation();
  }

  Future<void> _checkAndReapplyTranslation() async {
    final rootId = _talkTree['id'] ?? widget.talkNode['id'];
    if (rootId == null || _selectedNode == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTarget = prefs.getString('talk_translation_lang_$rootId');
      if (savedTarget != null && savedTarget.isNotEmpty && mounted) {
        final currentLang = _selectedNode?['language'] as String? ?? '';
        if (savedTarget != currentLang) {
          await _applyTranslation(savedTarget, savePreference: false);
        }
      }
    } catch (_) {}
  }

  Future<void> _applyTranslation(String targetLanguage, {bool savePreference = true}) async {
    if (_selectedNode == null) return;
    final currentText = (_selectedNode!['generated_text'] as String? ?? '').trim();
    if (currentText.isEmpty) return;

    final currentLanguage = _selectedNode!['language'] as String? ?? '';
    final rootId = _talkTree['id'] ?? widget.talkNode['id'];

    if (targetLanguage == currentLanguage) {
      if (savePreference && rootId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('talk_translation_lang_$rootId');
      }
      if (mounted) {
        setState(() {
          _viewingTranslation = false;
          _translatedLanguage = null;
          _translatedText = null;
        });
      }
      return;
    }

    if (_translatedLanguage == targetLanguage && _translatedText != null) {
      if (mounted) {
        setState(() {
          _viewingTranslation = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isTranslating = true;
        _errorMessage = '';
      });
    }

    try {
      final result = await ApiService.translateTalk(_selectedNode!['id'] as int, targetLanguage);
      if (mounted) {
        if (savePreference && rootId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('talk_translation_lang_$rootId', targetLanguage);
        }
        setState(() {
          _translatedLanguage = result['language'] as String? ?? targetLanguage;
          _translatedText = (result['text'] as String? ?? '').trim();
          _viewingTranslation = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  String _relativeTime(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 2) return 'dün';
    return '${diff.inDays} gün önce';
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
      _selectNode(newRequest);
      await _reloadData();
    } catch (e) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Submits a partial (section-level) update triggered from the floating
  /// text selection toolbar.
  Future<void> _submitPartialUpdate({
    required String selectedText,
    required String instruction,
  }) async {
    if (_selectedNode == null) return;

    // Hide toolbar and clear selection state immediately for UX
    _toolbarController.hide();
    setState(() {
      _isPartialSubmitting = true;
      _currentSelectedText = '';
      _errorMessage = '';
    });

    try {
      final newRequest = await ApiService.createTalkRequest(
        mode: 'partial_update',
        parentId: _selectedNode!['id'],
        instruction: instruction,
        selectedText: selectedText,
      );
      _selectNode(newRequest);
      await _reloadData();
    } catch (e) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPartialSubmitting = false;
        });
      }
    }
  }

  /// Snaps a raw selection range to full word boundaries so partial/cut-off
  /// words are automatically completed.
  TextSelection _getSnappedSelection(String fullText, TextSelection selection) {
    if (selection.isCollapsed || fullText.isEmpty) return selection;

    int start = selection.start.clamp(0, fullText.length);
    int end = selection.end.clamp(0, fullText.length);

    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    // Expand start backwards to start of word
    while (start > 0 && _isWordChar(fullText[start - 1])) {
      start--;
    }

    // Expand end forwards to end of word
    while (end < fullText.length && _isWordChar(fullText[end])) {
      end++;
    }

    return TextSelection(baseOffset: start, extentOffset: end);
  }

  String _snapToWordBoundaries(String fullText, TextSelection selection) {
    if (selection.isCollapsed || fullText.isEmpty) return '';
    final snapped = _getSnappedSelection(fullText, selection);
    return fullText.substring(snapped.start, snapped.end).trim();
  }

  bool _isWordChar(String char) {
    return RegExp(r'[\wÀ-ɏḀ-ỿ]').hasMatch(char);
  }

  Future<void> _submitManualUpdate({
    required String originalSelectedText,
    required String newSelectedText,
  }) async {
    if (_selectedNode == null) return;

    final currentFullText = _selectedNode!['generated_text'] as String? ?? '';
    if (currentFullText.isEmpty) return;

    String updatedFullText = currentFullText;
    if (originalSelectedText.isNotEmpty) {
      if (currentFullText.contains(originalSelectedText)) {
        updatedFullText = currentFullText.replaceFirst(originalSelectedText, newSelectedText);
      } else {
        final trimmed = originalSelectedText.trim();
        if (trimmed.isNotEmpty && currentFullText.contains(trimmed)) {
          updatedFullText = currentFullText.replaceFirst(trimmed, newSelectedText);
        }
      }
    }

    // Clean up multiple empty lines and trim leading/trailing space
    updatedFullText = updatedFullText
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    setState(() {
      _isPartialSubmitting = true;
      _currentSelectedText = '';
    });

    try {
      final lang = Provider.of<AuthProvider>(context, listen: false).language;
      final newRequest = await ApiService.createTalkRequest(
        mode: 'manual_update',
        parentId: _selectedNode!['id'],
        instruction: AppTranslations.tr('save_manual_edit', lang),
        selectedText: originalSelectedText,
        generatedText: updatedFullText,
      );
      _selectNode(newRequest);
      await _reloadData();
    } catch (e) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isAuthenticated) return;
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPartialSubmitting = false;
        });
      }
    }
  }

  /// Opens a picker with every supported language (minus whichever the
  /// current node is already in) and previews the current node's text
  /// translated into the one picked. This never creates a new version —
  /// it's just an alternate-language view of the same version; editing
  /// always continues from the original-language text underneath.
  Future<void> _pickLanguageAndTranslate() async {
    if (_selectedNode == null || _isTranslating) return;
    final currentText = _selectedNode!['generated_text'] as String? ?? '';
    if (currentText.isEmpty) return;

    final currentLanguage = _selectedNode!['language'] as String? ?? '';
    final activeLanguage = _viewingTranslation && _translatedLanguage != null
        ? _translatedLanguage!
        : currentLanguage;

    final options = <Map<String, String>>[];
    final currentLangItem = AppTranslations.supportedLanguages.firstWhere(
      (item) => item['code'] == currentLanguage,
      orElse: () => {'code': currentLanguage, 'symbol': '🌐'},
    );
    options.add(currentLangItem);

    for (final item in AppTranslations.supportedLanguages) {
      if (item['code'] != currentLanguage) {
        options.add(item);
      }
    }

    if (!mounted || options.isEmpty) return;
    final c = context.colors;

    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: c.surf,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: c.bordSoft, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle Indicator
                  Center(
                    child: Container(
                      width: 32,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: c.bord,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Compact Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: c.accSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.acc.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.translate_rounded, color: c.accTx, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hangi dile çevrilsin?',
                              style: GoogleFonts.schibstedGrotesk(
                                color: c.tx,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Seçilen dilde hızlı önizleme oluşturulur.',
                              style: GoogleFonts.schibstedGrotesk(
                                color: c.tx3,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(sheetContext),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: c.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bordSoft),
                          ),
                          child: Icon(Icons.close_rounded, color: c.tx2, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: c.bordSoft, height: 1),
                  const SizedBox(height: 10),
                  // Compact Language Item Cards List
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: options.map((item) {
                          final isCurrentNodeLang = item['code'] == currentLanguage;
                          final isCurrentlyActive = item['code'] == activeLanguage;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(sheetContext, item['code']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isCurrentlyActive ? c.accSoft : c.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentlyActive ? c.acc : c.bordSoft,
                                    width: isCurrentlyActive ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Flag Icon Container
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCurrentlyActive
                                            ? c.acc.withValues(alpha: 0.15)
                                            : c.surf,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isCurrentlyActive
                                              ? c.acc.withValues(alpha: 0.3)
                                              : c.bordSoft,
                                        ),
                                      ),
                                      child: Text(
                                        item['symbol']!,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Language Name & Badge
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            item['code']!,
                                            style: GoogleFonts.schibstedGrotesk(
                                              color: isCurrentlyActive ? c.accTx : c.tx,
                                              fontWeight: isCurrentlyActive ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          if (isCurrentNodeLang) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isCurrentlyActive ? c.acc : c.surf,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: isCurrentlyActive ? c.acc : c.bord,
                                                ),
                                              ),
                                              child: Text(
                                                'Orijinal Dil',
                                                style: GoogleFonts.schibstedGrotesk(
                                                  color: isCurrentlyActive ? Colors.white : c.tx2,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Selected Checkmark Badge / Chevron Indicator
                                    if (isCurrentlyActive)
                                      Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: c.acc,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                      )
                                    else
                                      Icon(Icons.chevron_right_rounded, color: c.tx3, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (target == null || !mounted) return;
    await _applyTranslation(target, savePreference: true);
  }

  /// Opens the floating editing toolbar only when the user finishes dragging and releases the mouse.
  void _handleSelectionCompleted() {
    final selected = _pendingSelectedText;
    if (selected.length < 10) return;

    if (selected == _currentSelectedText && _toolbarController.isVisible) return;

    setState(() => _currentSelectedText = selected);

    final RenderBox? box = _textContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final containerOffset = box.localToGlobal(Offset.zero);
    final containerSize = box.size;
    final text = (_selectedNode?['generated_text'] as String? ?? '').trim();

    Rect anchorRect;
    if (_currentTextSelection != null && !_currentTextSelection!.isCollapsed && text.isNotEmpty) {
      final snappedSelection = _getSnappedSelection(text, _currentTextSelection!);
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.schibstedGrotesk(
            fontSize: 15,
            height: 1.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: containerSize.width);

      final boxes = textPainter.getBoxesForSelection(snappedSelection);
      if (boxes.isNotEmpty) {
        double minX = double.infinity;
        double maxX = -double.infinity;
        double minY = double.infinity;
        double maxY = -double.infinity;

        for (final b in boxes) {
          if (b.left < minX) minX = b.left;
          if (b.right > maxX) maxX = b.right;
          if (b.top < minY) minY = b.top;
          if (b.bottom > maxY) maxY = b.bottom;
        }

        final selectionLocalRect = Rect.fromLTRB(minX, minY, maxX, maxY);
        anchorRect = selectionLocalRect.shift(containerOffset);
      } else {
        anchorRect = Rect.fromLTWH(
          containerOffset.dx,
          containerOffset.dy,
          containerSize.width,
          containerSize.height,
        );
      }
    } else {
      anchorRect = Rect.fromLTWH(
        containerOffset.dx,
        containerOffset.dy,
        containerSize.width,
        containerSize.height,
      );
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final overlay = Overlay.of(context);
    _toolbarController.show(
      overlay: overlay,
      anchorRect: anchorRect,
      selectedText: selected,
      lang: authProvider.language,
      onSubmit: (selText, instruction) {
        _submitPartialUpdate(
          selectedText: selText,
          instruction: instruction,
        );
      },
      onManualSubmit: (origText, updatedText) {
        _submitManualUpdate(
          originalSelectedText: origText,
          newSelectedText: updatedText,
        );
      },
      onDismiss: () {
        setState(() => _currentSelectedText = '');
      },
    );
  }

  Future<void> _deleteVersionNode(Map<String, dynamic> node) async {
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    final flatNodes = _flattenTree(_talkTree, 0);

    if (flatNodes.length <= 1) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2000),
          content: Text(AppTranslations.tr('cannot_delete_only_version', lang)),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final c = context.colors;
    final nodeId = node['id'] as int;
    final isRoot = node['parent_id'] == null || nodeId == _talkTree['id'];
    final versionLabel = _getVersionLabel(node);

    final titleText = isRoot
        ? '${AppTranslations.tr('delete_version', lang)} (Kök)'
        : '${AppTranslations.tr('delete_version', lang)} (#$versionLabel)';
    final contentText = AppTranslations.tr('confirm_delete_version', lang);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.bord, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerTx.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: AppColors.dangerTx, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                style: GoogleFonts.schibstedGrotesk(
                  color: c.tx,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          contentText,
          style: GoogleFonts.schibstedGrotesk(
            color: c.tx2,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppTranslations.tr('cancel', lang),
              style: GoogleFonts.schibstedGrotesk(
                color: c.tx3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(
              AppTranslations.tr('delete', lang),
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
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (!authProvider.isAuthenticated) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 2500),
              content: Text('${AppTranslations.tr('error', lang)}: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  void _copyToClipboard(String text, String lang) {
    final c = context.colors;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              AppTranslations.tr('speech_copied', lang),
              style: GoogleFonts.schibstedGrotesk(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: c.acc,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  void _openShareSheet(String text) {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paylaş', style: GoogleFonts.schibstedGrotesk(color: c.tx, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ShareButtons(text: text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required AppColors c,
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surf,
              border: Border.all(color: c.bord),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: c.accTx))
                : Icon(icon, size: 17, color: c.tx2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
    final c = context.colors;
    final flatNodes = _flattenTree(_talkTree, 0);
    flatNodes.sort((a, b) {
      final idA = (a.node['id'] as num?)?.toInt() ?? 0;
      final idB = (b.node['id'] as num?)?.toInt() ?? 0;
      return idB.compareTo(idA);
    });

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTx.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.dangerBord),
                ),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx, fontSize: 13),
                ),
              ),
            if (_isReloading)
              LinearProgressIndicator(minHeight: 2, color: c.acc, backgroundColor: Colors.transparent),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return SingleChildScrollView(
                    padding: isWide
                        ? const EdgeInsets.fromLTRB(28, 20, 28, 40)
                        : const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(lang, c),
                            const SizedBox(height: 18),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildContentColumn(flatNodes, lang, c, isCompact: false)),
                                  const SizedBox(width: 20),
                                  SizedBox(width: 260, child: _buildVersionRail(flatNodes, lang, c)),
                                ],
                              )
                            else
                              _buildContentColumn(flatNodes, lang, c, isCompact: true),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String lang, AppColors c) {
    final topic = _talkTree['topic'] as String? ?? '';
    final metaParts = <String>[
      AppTranslations.translateSpeechType(_talkTree['speech_type'], lang),
      (_talkTree['place'] as String?) ?? '',
      '${_talkTree['duration'] ?? 0} ${AppTranslations.tr('minutes', lang)}',
      AppTranslations.translateLanguageName(_talkTree['language'], lang),
    ].where((p) => p.isNotEmpty).toList();

    final isCompleted = _selectedNode?['status'] == 'completed';
    final text = (_selectedNode?['generated_text'] as String? ?? '').trim();
    final displayedText = (_viewingTranslation && _translatedText != null) ? _translatedText! : text;
    final hasText = isCompleted && text.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 4),
            child: Icon(Icons.arrow_back, size: 22, color: c.tx2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.schibstedGrotesk(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.tx),
              ),
              const SizedBox(height: 2),
              Text(
                metaParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.schibstedGrotesk(fontSize: 12, color: c.tx3),
              ),
            ],
          ),
        ),
        if (hasText) ...[
          _headerIconAction(
            icon: Icons.content_copy,
            tooltip: AppTranslations.tr('copy_speech', lang),
            onTap: () => _copyToClipboard(displayedText, lang),
            c: c,
          ),
          _headerIconAction(
            icon: Icons.ios_share,
            tooltip: 'Paylaş',
            onTap: () => _openShareSheet(displayedText),
            c: c,
          ),
          _headerIconAction(
            icon: Icons.translate_rounded,
            tooltip: AppTranslations.tr('translate_button', lang),
            onTap: _isTranslating ? null : _pickLanguageAndTranslate,
            loading: _isTranslating,
            c: c,
          ),
        ],
      ],
    );
  }

  Widget _buildVersionPillsRow(List<FlatTreeNode> flatNodes, String lang, AppColors c) {
    if (_selectedNode == null) return const SizedBox.shrink();

    final parentId = _selectedNode?['parent_id'];
    final parentNode = parentId != null ? _findNodeInTree(_talkTree, parentId as int) : null;
    final selHasParent = parentNode != null && _selectedNode?['status'] == 'completed';
    final latestNode = _getLatestNode(_talkTree);
    final latestId = (latestNode['id'] as num?)?.toInt() ?? 0;
    final selectedId = (_selectedNode!['id'] as num?)?.toInt() ?? 0;

    // Pre-order tree list for hierarchical display
    final treeList = _flattenTree(_talkTree, 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: c.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isVersionHistoryExpanded ? c.acc.withValues(alpha: 0.4) : c.bordSoft,
          width: 1,
        ),
        boxShadow: [
          if (_isVersionHistoryExpanded)
            BoxShadow(
              color: c.acc.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Crisp Header Bar (Summary View)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Left: Active version badge & Diff button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () {
                        if (!_isVersionHistoryExpanded && treeList.length > 1) {
                          setState(() => _isVersionHistoryExpanded = true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.accSoft,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: c.acc),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers_rounded, size: 14, color: c.accTx),
                            const SizedBox(width: 6),
                            Text(
                              '${AppTranslations.tr('version', lang)} ${_getVersionLabel(_selectedNode!)}',
                              style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, fontWeight: FontWeight.bold, color: c.accTx),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.acc,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppTranslations.tr('active_version', lang),
                                style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            if (selectedId == latestId && treeList.length > 1) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.completed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppTranslations.tr('latest_version', lang),
                                  style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (selHasParent) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => setState(() => _viewDiff = !_viewDiff),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _viewDiff ? c.acc : c.bg,
                            borderRadius: BorderRadius.circular(99),
                            border: _viewDiff ? null : Border.all(color: c.bord),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _viewDiff ? Icons.difference : Icons.difference_outlined,
                                size: 14,
                                color: _viewDiff ? Colors.white : c.tx2,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Diff',
                                style: GoogleFonts.schibstedGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _viewDiff ? Colors.white : c.tx2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (treeList.length > 1)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _isVersionHistoryExpanded = !_isVersionHistoryExpanded),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isVersionHistoryExpanded ? c.accSoft : c.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isVersionHistoryExpanded ? c.acc : c.bord),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 15,
                            color: _isVersionHistoryExpanded ? c.accTx : c.tx2,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isVersionHistoryExpanded
                                ? AppTranslations.tr('collapse_version_history', lang)
                                : '${AppTranslations.tr('show_version_history', lang)} (${treeList.length})',
                            style: GoogleFonts.schibstedGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isVersionHistoryExpanded ? c.accTx : c.tx,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: _isVersionHistoryExpanded ? 0.5 : 0.0,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: _isVersionHistoryExpanded ? c.accTx : c.tx2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Expanded Content (Timeline Tree Accordion Body)
          if (_isVersionHistoryExpanded && treeList.length > 1) ...[
            Divider(color: c.bordSoft, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree_rounded, size: 16, color: c.accTx),
                      const SizedBox(width: 8),
                      Text(
                        '${AppTranslations.tr('version_tree', lang).toUpperCase()} (${treeList.length})',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.tx3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(treeList.length, (index) {
                    final flat = treeList[index];
                    final node = flat.node;
                    final depth = flat.depth;
                    final nodeId = (node['id'] as num?)?.toInt() ?? 0;
                    final isSelected = selectedId == nodeId;
                    final isLatest = latestId == nodeId;
                    final isRoot = node['parent_id'] == null;
                    final versionLabel = _getVersionLabel(node);
                    final isLast = index == treeList.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Tree Branch Connector / Indentation Guide
                          SizedBox(
                            width: (depth * 20.0 + 24.0).clamp(24.0, 120.0),
                            child: CustomPaint(
                              painter: _TreeBranchPainter(
                                depth: depth,
                                isRoot: isRoot,
                                isLast: isLast,
                                isSelected: isSelected,
                                color: c.acc,
                                lineTileColor: c.bord.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          // Version Card Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _selectNode(node),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? c.accSoft : c.bg.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? c.acc : c.bordSoft.withValues(alpha: 0.6),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: c.acc.withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              '${AppTranslations.tr('version', lang)} $versionLabel',
                                              style: GoogleFonts.schibstedGrotesk(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? c.accTx : c.tx,
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: c.acc,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  AppTranslations.tr('active_version', lang),
                                                  style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                                                ),
                                              ),
                                            if (isLatest)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.completed,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  AppTranslations.tr('latest_version', lang),
                                                  style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                                                ),
                                              ),
                                            if (isRoot)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: c.surf,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: c.bordSoft),
                                                ),
                                                child: Text(
                                                  AppTranslations.tr('root_version', lang),
                                                  style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w600, color: c.tx2),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _relativeTime(node['created_at']),
                                            style: GoogleFonts.schibstedGrotesk(fontSize: 10.5, color: c.tx3),
                                          ),
                                          if (treeList.length > 1)
                                            InkWell(
                                              onTap: () => _deleteVersionNode(node),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: Icon(Icons.delete_outline_rounded, size: 15, color: c.tx3),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _isVersionHistoryExpanded = false),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                      label: Text(
                        AppTranslations.tr('collapse_version_history', lang),
                        style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: c.tx2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionRail(List<FlatTreeNode> flatNodes, String lang, AppColors c) {
    final treeList = _flattenTree(_talkTree, 0);
    final latestNode = _getLatestNode(_talkTree);
    final latestId = (latestNode['id'] as num?)?.toInt() ?? 0;
    final selectedId = (_selectedNode?['id'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_tree_rounded, size: 16, color: c.accTx),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${AppTranslations.tr('version_tree', lang).toUpperCase()} (${treeList.length})',
                style: GoogleFonts.schibstedGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.tx3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(treeList.length, (index) {
          final flat = treeList[index];
          final node = flat.node;
          final depth = flat.depth;
          final nodeId = (node['id'] as num?)?.toInt() ?? 0;
          final isSelected = selectedId == nodeId;
          final isLatest = latestId == nodeId;
          final isRoot = node['parent_id'] == null;
          final versionLabel = _getVersionLabel(node);
          final isLast = index == treeList.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: (depth * 14.0 + 18.0).clamp(18.0, 70.0),
                  child: CustomPaint(
                    painter: _TreeBranchPainter(
                      depth: depth,
                      isRoot: isRoot,
                      isLast: isLast,
                      isSelected: isSelected,
                      color: c.acc,
                      lineTileColor: c.bord.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _selectNode(node),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? c.accSoft : c.surf.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? c.acc : c.bordSoft.withValues(alpha: 0.6), width: isSelected ? 1.5 : 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${AppTranslations.tr('version', lang)} $versionLabel',
                                    style: GoogleFonts.schibstedGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? c.accTx : c.tx),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: c.acc,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        AppTranslations.tr('active_version', lang),
                                        style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.completed,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        AppTranslations.tr('latest_version', lang),
                                        style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                  if (isRoot)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: c.surf,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: c.bordSoft),
                                      ),
                                      child: Text(
                                        AppTranslations.tr('root_version', lang),
                                        style: GoogleFonts.schibstedGrotesk(fontSize: 9.5, fontWeight: FontWeight.w600, color: c.tx3),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _relativeTime(node['created_at']),
                                  style: GoogleFonts.schibstedGrotesk(fontSize: 10.5, color: c.tx3),
                                ),
                                if (treeList.length > 1)
                                  InkWell(
                                    onTap: () => _deleteVersionNode(node),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(Icons.delete_outline_rounded, size: 15, color: c.tx3),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Returns a [TextSpan] where the first occurrence of [highlighted] is styled
  /// with an accent background, ensuring selected text remains visually distinct
  /// even when focus moves to the toolbar popup, without interrupting Flutter's native
  /// text selection handling.
  TextSpan _buildSelectableTextSpan(String fullText, String highlighted, AppColors c) {
    final baseStyle = GoogleFonts.schibstedGrotesk(
      color: c.tx,
      fontSize: 15,
      height: 1.8,
    );

    if (highlighted.isEmpty) {
      return TextSpan(text: fullText, style: baseStyle);
    }

    final idx = fullText.indexOf(highlighted);
    if (idx < 0) {
      return TextSpan(text: fullText, style: baseStyle);
    }

    final before = fullText.substring(0, idx);
    final match = fullText.substring(idx, idx + highlighted.length);
    final after = fullText.substring(idx + highlighted.length);

    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: before),
        TextSpan(
          text: match,
          style: baseStyle.copyWith(
            backgroundColor: c.acc.withValues(alpha: 0.35),
            color: c.tx,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: after),
      ],
    );
  }

  Widget _buildContentColumn(List<FlatTreeNode> flatNodes, String lang, AppColors c, {required bool isCompact}) {
    if (_selectedNode == null) return const SizedBox.shrink();

    final parentId = _selectedNode!['parent_id'];
    final parentNode = parentId != null ? _findNodeInTree(_talkTree, parentId as int) : null;
    final isCompleted = _selectedNode!['status'] == 'completed';
    final text = (_selectedNode!['generated_text'] as String? ?? '').trim();
    final wordCount = _countWords(text);
    final readTimeMinutes = wordCount == 0 ? 0 : (wordCount / 130).ceil();
    final suggestions = _getQuickSuggestions(lang);
    final isRootNode = _selectedNode!['parent_id'] == null;
    final vLabel = _getVersionLabel(_selectedNode!);
    final captionLeft = _selectedNode!['instruction'] != null
        ? '${AppTranslations.tr('version', lang).toUpperCase()} $vLabel · "${_selectedNode!['instruction']}"'
        : (isRootNode ? '${AppTranslations.tr('version', lang).toUpperCase()} $vLabel · KÖK' : '${AppTranslations.tr('version', lang).toUpperCase()} $vLabel');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVersionPillsRow(flatNodes, lang, c),
        const SizedBox(height: 12),
        if (_translatedText != null && _viewingTranslation) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Bu bir önizleme çevirisidir ve kaydedilmez. Düzenlemeler her zaman orijinal dilden devam eder.',
              style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
        if (_viewingTranslation && _translatedText != null)
          Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(minHeight: 240),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.bordSoft),
            ),
            child: SelectableText(
              _translatedText!,
              style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 15, height: 1.8),
            ),
          )
        else if (_isTranslating)
          Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(minHeight: 240),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.bordSoft),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: c.acc),
                  const SizedBox(height: 16),
                  Text(
                    'Çeviri yükleniyor...',
                    style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else if (_viewDiff && parentNode != null && isCompleted)
          TalkDiffView(
            parentText: parentNode['generated_text'] ?? '',
            childText: text,
            parentId: _getVersionLabel(parentNode),
            childId: _getVersionLabel(_selectedNode!),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(minHeight: 240),
            decoration: BoxDecoration(
              color: c.surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.bordSoft),
            ),
            child: (_selectedNode!['status'] == 'pending' || _selectedNode!['status'] == 'processing')
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: c.acc),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.tr('status_generating', lang),
                          style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _isPartialSubmitting
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: c.acc),
                            const SizedBox(height: 16),
                            Text(
                              AppTranslations.tr('status_generating', lang),
                              style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (text.isNotEmpty) ...[
                            Text(
                              captionLeft,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: c.tx3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$wordCount ${AppTranslations.tr("words", lang).toUpperCase()} · ~$readTimeMinutes ${AppTranslations.tr("minutes", lang).toUpperCase()}',
                              style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: c.tx3),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: c.bordSoft, height: 1),
                            const SizedBox(height: 14),
                          ],
                          Container(
                            key: _textContainerKey,
                            child: Listener(
                              onPointerUp: (_) {
                                _selectionDebounce?.cancel();
                                _handleSelectionCompleted();
                              },
                              child: SelectableText.rich(
                                _buildSelectableTextSpan(text, _currentSelectedText, c),
                                selectionColor: c.acc.withValues(alpha: 0.4),
                                onSelectionChanged: (selection, cause) {
                                  _currentTextSelection = selection;

                                  // Extract the selected substring snapped to full word boundaries
                                  final selected = _snapToWordBoundaries(text, selection);

                                  _pendingSelectedText = selected;

                                  // Dismiss on empty / too-short selection
                                  if (selected.length < 10) {
                                    _selectionDebounce?.cancel();
                                    if (_toolbarController.isVisible) {
                                      _toolbarController.hide();
                                      setState(() => _currentSelectedText = '');
                                    }
                                    return;
                                  }

                                  // On mobile, dragging the selection handles doesn't fire
                                  // Listener.onPointerUp (the handles live in a separate
                                  // overlay and consume the touch themselves), so
                                  // _handleSelectionCompleted would never run there. Debounce
                                  // on every selection change as a cross-platform fallback:
                                  // once the selection stops moving for a short pause, treat
                                  // it as final and show the toolbar.
                                  _selectionDebounce?.cancel();
                                  _selectionDebounce = Timer(
                                    const Duration(milliseconds: 400),
                                    _handleSelectionCompleted,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        if (isCompleted) ...[
          const SizedBox(height: 18),
          _buildComposer(lang, c, isCompact, suggestions),
        ],
        if (_selectedNode!['room_id'] != null) ...[
          const SizedBox(height: 20),
          DiscussionPanel(
            key: ValueKey(_selectedNode!['id']),
            talkId: _selectedNode!['id'] as int,
            roomId: _selectedNode!['room_id'] as int,
            onVersionGenerated: _reloadData,
          ),
        ],
      ],
    );
  }

  Widget _buildComposer(String lang, AppColors c, bool isCompact, List<String> suggestions) {
    final hasInstruction = _instructionController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions.map((s) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => setState(() => _instructionController.text = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.surf,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.bord),
                    ),
                    child: Text(s, style: GoogleFonts.schibstedGrotesk(fontSize: 11.5, color: c.accTx)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: c.surf,
            border: Border.all(color: c.bord),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _instructionController,
                  maxLines: isCompact ? 4 : 1,
                  minLines: 1,
                  style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: AppTranslations.tr('update_instruction_hint', lang),
                    hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: (_isSubmitting || !hasInstruction) ? null : _submitUpdate,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_isSubmitting || !hasInstruction) ? c.bord : c.acc,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: _isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.arrow_upward_rounded, color: hasInstruction ? Colors.white : c.tx3, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TreeBranchPainter extends CustomPainter {
  final int depth;
  final bool isRoot;
  final bool isLast;
  final bool isSelected;
  final Color color;
  final Color lineTileColor;

  _TreeBranchPainter({
    required this.depth,
    required this.isRoot,
    required this.isLast,
    required this.isSelected,
    required this.color,
    required this.lineTileColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineTileColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = isSelected ? color : lineTileColor
      ..style = PaintingStyle.fill;

    final cx = size.width - 10;
    final cy = (size.height / 2).clamp(16.0, 22.0);

    if (depth > 0) {
      final path = Path();
      path.moveTo(6.0, 0);
      path.lineTo(6.0, cy - 4);
      path.quadraticBezierTo(6.0, cy, 12.0, cy);
      path.lineTo(cx - 3, cy);
      canvas.drawPath(path, linePaint);
    }

    if (!isLast) {
      canvas.drawLine(const Offset(6.0, 0), Offset(6.0, size.height), linePaint);
    }

    // Draw node dot
    canvas.drawCircle(Offset(cx, cy), isSelected ? 4.5 : 3.0, dotPaint);
    if (isSelected) {
      final ringPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), 7.5, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isLast != isLast;
  }
}
