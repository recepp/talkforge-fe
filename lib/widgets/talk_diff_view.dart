import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

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
  int _viewMode = 0; // 0: Inline, 1: Side by Side
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
    final lang = Provider.of<AuthProvider>(context).language;
    final c = context.colors;
    final versionLabel = AppTranslations.tr('version', lang);
    final wordsLabel = AppTranslations.tr('words', lang);

    return Container(
      decoration: BoxDecoration(
        color: c.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.bordSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surf2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: c.bordSoft)),
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
                          '$versionLabel ${widget.parentId} ➔ $versionLabel ${widget.childId}',
                          style: GoogleFonts.schibstedGrotesk(
                            color: c.tx,
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
                            color: AppColors.completed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.completed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: AppColors.completed),
                              const SizedBox(width: 2),
                              Text(
                                '+$_additionsCount $wordsLabel',
                                style: GoogleFonts.schibstedGrotesk(
                                  color: AppColors.completed,
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
                            color: AppColors.failed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.failed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove, size: 12, color: AppColors.failed),
                              const SizedBox(width: 2),
                              Text(
                                '-$_deletionsCount $wordsLabel',
                                style: GoogleFonts.schibstedGrotesk(
                                  color: AppColors.failed,
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
                        color: c.surf,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.bord),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeTab(
                            title: lang == 'en' ? 'Inline' : 'Bütünleşik',
                            icon: Icons.view_headline_rounded,
                            index: 0,
                            c: c,
                          ),
                          _buildModeTab(
                            title: lang == 'en' ? 'Side by Side' : 'Yan Yana',
                            icon: Icons.view_column_rounded,
                            index: 1,
                            c: c,
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
            child: _viewMode == 0 ? _buildInlineDiff(c) : _buildSideBySideDiff(c, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required int index,
    required AppColors c,
  }) {
    final isActive = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? c.acc : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : c.tx3,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.schibstedGrotesk(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : c.tx3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDiff(AppColors c) {
    List<InlineSpan> spans = [];

    for (final d in _diffs) {
      if (d.operation == DIFF_INSERT) {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.schibstedGrotesk(
              color: AppColors.completed,
              backgroundColor: AppColors.completed.withValues(alpha: 0.2),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (d.operation == DIFF_DELETE) {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.schibstedGrotesk(
              color: AppColors.failed,
              backgroundColor: AppColors.failed.withValues(alpha: 0.2),
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.failed,
              decorationThickness: 2,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.schibstedGrotesk(color: c.tx),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
  }

  Widget _buildSideBySideDiff(AppColors c, String lang) {
    List<InlineSpan> parentSpans = [];
    List<InlineSpan> childSpans = [];
    final versionLabel = AppTranslations.tr('version', lang);

    for (final d in _diffs) {
      if (d.operation == DIFF_DELETE) {
        parentSpans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.schibstedGrotesk(
              color: AppColors.failed,
              backgroundColor: AppColors.failed.withValues(alpha: 0.2),
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.failed,
            ),
          ),
        );
      } else if (d.operation == DIFF_INSERT) {
        childSpans.add(
          TextSpan(
            text: d.text,
            style: GoogleFonts.schibstedGrotesk(
              color: AppColors.completed,
              backgroundColor: AppColors.completed.withValues(alpha: 0.2),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        final span = TextSpan(
          text: d.text,
          style: GoogleFonts.schibstedGrotesk(color: c.tx),
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
            color: c.surf2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.bord),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 14, color: c.tx3),
                  const SizedBox(width: 6),
                  Text(
                    'Parent $versionLabel (${widget.parentId})',
                    style: GoogleFonts.schibstedGrotesk(
                      color: c.tx3,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Divider(color: c.bord, height: 16),
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
            color: c.surf2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.bord),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.new_releases_outlined, size: 14, color: c.accTx),
                  const SizedBox(width: 6),
                  Text(
                    'New $versionLabel (${widget.childId})',
                    style: GoogleFonts.schibstedGrotesk(
                      color: c.accTx,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Divider(color: c.bord, height: 16),
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

