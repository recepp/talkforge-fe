import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_translations.dart';

/// Controller that manages the lifecycle of a [TextSelectionToolbar].
/// Attach it to a [SelectionArea] and call [show]/[hide] from the selection
/// change callback.
class TextSelectionToolbarController {
  OverlayEntry? _overlayEntry;
  bool get isVisible => _overlayEntry != null;

  /// Shows the floating toolbar anchored near [anchorRect] inside [overlay].
  ///
  /// [selectedText]  – The passage the user highlighted.
  /// [lang]          – App language code for translations.
  /// [onSubmit]      – Called with (selectedText, instruction) when the user
  ///                   taps "Generate New Version".
  /// [onDismiss]     – Called when the toolbar is closed by the user.
  void show({
    required OverlayState overlay,
    required Rect anchorRect,
    required String selectedText,
    required String lang,
    required void Function(String selectedText, String instruction) onSubmit,
    required VoidCallback onDismiss,
  }) {
    hide(); // Remove any existing overlay first

    _overlayEntry = OverlayEntry(
      builder: (context) => _TextSelectionToolbarOverlay(
        anchorRect: anchorRect,
        selectedText: selectedText,
        lang: lang,
        onSubmit: (instruction) {
          hide();
          onSubmit(selectedText, instruction);
        },
        onDismiss: () {
          hide();
          onDismiss();
        },
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  /// Removes the toolbar from the overlay stack.
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void dispose() {
    hide();
  }
}

// ---------------------------------------------------------------------------
// Internal overlay widget
// ---------------------------------------------------------------------------

class _TextSelectionToolbarOverlay extends StatefulWidget {
  final Rect anchorRect;
  final String selectedText;
  final String lang;
  final void Function(String instruction) onSubmit;
  final VoidCallback onDismiss;

  const _TextSelectionToolbarOverlay({
    required this.anchorRect,
    required this.selectedText,
    required this.lang,
    required this.onSubmit,
    required this.onDismiss,
  });

  @override
  State<_TextSelectionToolbarOverlay> createState() =>
      _TextSelectionToolbarOverlayState();
}

class _TextSelectionToolbarOverlayState
    extends State<_TextSelectionToolbarOverlay>
    with SingleTickerProviderStateMixin {
  final _instructionController = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty) return;
    widget.onSubmit(instruction);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Toolbar dimensions
    const toolbarWidth = 340.0;
    const toolbarHeight = 240.0;
    const arrowHeight = 10.0;
    const padding = 12.0;

    // Position: prefer above the anchor, fall back to below
    double left = widget.anchorRect.left +
        (widget.anchorRect.width / 2) -
        (toolbarWidth / 2);
    left = left.clamp(padding, screenSize.width - toolbarWidth - padding);

    bool showAbove = widget.anchorRect.top - toolbarHeight - arrowHeight > 0;
    double top = showAbove
        ? widget.anchorRect.top - toolbarHeight - arrowHeight
        : widget.anchorRect.bottom + arrowHeight;

    return Stack(
      children: [
        // Floating toolbar card positioned near selection
        Positioned(
          left: left,
          top: top,
          width: toolbarWidth,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buildCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final lang = widget.lang;
    final preview = widget.selectedText.length > 100
        ? '${widget.selectedText.substring(0, 100)}\u2026'
        : widget.selectedText;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.18),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFA5B4FC),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppTranslations.tr('edit_selection', lang),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Selected Text Preview ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.tr('selected_text_preview', lang)
                          .toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF818CF8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '\u201c$preview\u201d',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Instruction Input ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: TextField(
                  controller: _instructionController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  minLines: 1,
                  onSubmitted: (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    hintText:
                        AppTranslations.tr('edit_selection_hint', lang),
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                  ),
                ),
              ),

              // ── Action Button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleSubmit,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: Text(
                      AppTranslations.tr('generate_new_version', lang),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
