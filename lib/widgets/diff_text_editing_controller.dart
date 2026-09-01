import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../theme/app_theme.dart';

/// A [TextEditingController] that compares its current [text] with [originalText]
/// using [DiffMatchPatch] and highlights added/modified text spans in accent color.
class DiffTextEditingController extends TextEditingController {
  String originalText;
  AppColors? colors;
  final DiffMatchPatch _dmp = DiffMatchPatch();

  DiffTextEditingController({
    super.text,
    this.originalText = '',
    this.colors,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ??
        GoogleFonts.schibstedGrotesk(
          fontSize: 15,
          height: 1.8,
        );

    final c = colors;
    final orig = originalText.trim();
    final current = text.trim();

    // If there is no original text, no current text, no difference, or no colors, use default rendering
    if (orig.isEmpty || current.isEmpty || orig == current || c == null) {
      return super.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: withComposing,
      );
    }

    final diffs = _dmp.diff(orig, text);
    _dmp.diffCleanupSemantic(diffs);

    final spans = <InlineSpan>[];
    for (final d in diffs) {
      if (d.operation == DIFF_EQUAL) {
        spans.add(TextSpan(text: d.text, style: baseStyle));
      } else if (d.operation == DIFF_INSERT) {
        spans.add(
          TextSpan(
            text: d.text,
            style: baseStyle.copyWith(
              color: c.accTx,
              backgroundColor: c.acc.withValues(alpha: 0.25),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      // DIFF_DELETE is not present in the current editable text
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}
