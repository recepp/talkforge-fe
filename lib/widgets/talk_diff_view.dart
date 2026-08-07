import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

// diff_match_patch 0.4.1 API:
// - dmp.diff(text1, text2)  → List<Diff>
// - dmp.diffCleanupSemantic(diffs)
// - diff.operation: DIFF_INSERT (1), DIFF_DELETE (-1), DIFF_EQUAL (0)

class TalkDiffView extends StatefulWidget {
  final String parentText;
  final String childText;
  final dynamic parentId;
  final dynamic childId;

  const TalkDiffView({
    super.key,
    required this.parentText,
    required this.childText,
    required this.parentId,
    required this.childId,
  });

  @override
  State<TalkDiffView> createState() => _TalkDiffViewState();
}

class _TalkDiffViewState extends State<TalkDiffView> {
  int _viewMode = 0; // 0: Inline (Bütünleşik), 1: Side by Side (Yan Yana)
  late List<Diff> _diffs;

  int _additionsCount = 0;
  int _deletionsCount = 0;

  @override
  void initState() {
    super.initState();
    _computeDiffs();
  }

  @override
  void didUpdateWidget(covariant TalkDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentText != widget.parentText ||
        oldWidget.childText != widget.childText) {
      _computeDiffs();
    }
  }

  void _computeDiffs() {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(widget.parentText, widget.childText);
    dmp.diffCleanupSemantic(diffs);

    int addCount = 0;
    int delCount = 0;

    for (final d in diffs) {
      final words = _countWords(d.text);
      if (d.operation == DIFF_INSERT) {
        addCount += words;
      } else if (d.operation == DIFF_DELETE) {
        delCount += words;
      }
    }

    setState(() {
      _diffs = diffs;
      _additionsCount = addCount;
      _deletionsCount = delCount;
    });
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 520;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: isWide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    // Version info & stat badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Sürüm #${widget.parentId} ➔ Sürüm #${widget.childId}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Addition Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x2610B981),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  size: 12, color: Color(0xFF34D399)),
                              const SizedBox(width: 2),
                              Text(
                                '+$_additionsCount kelime',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF34D399),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Deletion Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x26EF4444),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove,
                                  size: 12, color: Color(0xFFF87171)),
                              const SizedBox(width: 2),
                              Text(
                                '-$_deletionsCount kelime',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF87171),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (!isWide) const SizedBox(height: 10),

                    // Toggle View Mode Buttons
                    Container(
                      height: 32,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeTab(
                            title: 'Bütünleşik',
                            icon: Icons.view_headline_rounded,
                            index: 0,
                          ),
                          _buildModeTab(
                            title: 'Yan Yana',
                            icon: Icons.view_column_rounded,
                            index: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Diff Content Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _viewMode == 0 ? _buildInlineDiff() : _buildSideBySideDiff(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(
      {required String title, required IconData icon, required int index}) {
    final isActive = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDiff() {
    List<InlineSpan> spans = [];

    for (final d in _diffs) {
      if (d.operation == DIFF_INSERT) {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.roboto(
              color: const Color(0xFF6EE7B7),
              backgroundColor: const Color(0x3310B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (d.operation == DIFF_DELETE) {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.roboto(
              color: const Color(0xFFFCA5A5),
              backgroundColor: const Color(0x33EF4444),
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFFEF4444),
              decorationThickness: 2,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.roboto(color: const Color(0xFFE2E8F0)),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
  }

  Widget _buildSideBySideDiff() {
    List<InlineSpan> parentSpans = [];
    List<InlineSpan> childSpans = [];

    for (final d in _diffs) {
      if (d.operation == DIFF_DELETE) {
        parentSpans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.roboto(
              color: const Color(0xFFFCA5A5),
              backgroundColor: const Color(0x33EF4444),
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFFEF4444),
            ),
          ),
        );
      } else if (d.operation == DIFF_INSERT) {
        childSpans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.roboto(
              color: const Color(0xFF6EE7B7),
              backgroundColor: const Color(0x3310B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        final span = TextSpan(
          text: d.text,
          style: GoogleFonts.roboto(color: const Color(0xFFE2E8F0)),
        );
        parentSpans.add(span);
        childSpans.add(span);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final parentWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Ebeveyn Sürüm (#${widget.parentId})',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 16),
              SelectableText.rich(
                TextSpan(children: parentSpans),
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        );

        final childWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.new_releases_outlined,
                      size: 14, color: Color(0xFF818CF8)),
                  const SizedBox(width: 6),
                  Text(
                    'Yeni Sürüm (#${widget.childId})',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF818CF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 16),
              SelectableText.rich(
                TextSpan(children: childSpans),
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        );

        if (isMobile) {
          return Column(
            children: [
              parentWidget,
              const SizedBox(height: 12),
              childWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: parentWidget),
            const SizedBox(width: 12),
            Expanded(child: childWidget),
          ],
        );
      },
    );
  }
}
