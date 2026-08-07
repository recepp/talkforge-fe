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
  void show({
    required OverlayState overlay,
    required Rect anchorRect,
    required String selectedText,
    required String lang,
    required void Function(String selectedText, String instruction) onSubmit,
    required void Function(String originalText, String updatedText) onManualSubmit,
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
        onManualSubmit: (updatedText) {
          hide();
          onManualSubmit(selectedText, updatedText);
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
  final void Function(String updatedText) onManualSubmit;
  final VoidCallback onDismiss;

  const _TextSelectionToolbarOverlay({
    required this.anchorRect,
    required this.selectedText,
    required this.lang,
    required this.onSubmit,
    required this.onManualSubmit,
    required this.onDismiss,
  });

  @override
  State<_TextSelectionToolbarOverlay> createState() =>
      _TextSelectionToolbarOverlayState();
}

class _TextSelectionToolbarOverlayState
    extends State<_TextSelectionToolbarOverlay>
    with SingleTickerProviderStateMixin {
  late TextEditingController _selectedTextController;
  final _instructionController = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _selectedTextController = TextEditingController(text: widget.selectedText);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _selectedTextController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _handleAISubmit() {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty) return;
    widget.onSubmit(instruction);
  }

  void _handleManualSubmit() {
    final updatedText = _selectedTextController.text;
    widget.onManualSubmit(updatedText);
  }

  void _clearSelectedText() {
    setState(() {
      _selectedTextController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Spacious responsive width for comfortable desktop/tablet reading
    final double toolbarWidth = screenSize.width > 900
        ? 780.0
        : (screenSize.width - 32.0).clamp(320.0, 780.0);

    // Center modal nicely on screen
    double left = (screenSize.width - toolbarWidth) / 2;
    left = left.clamp(16.0, screenSize.width - toolbarWidth - 16.0);

    double top = ((screenSize.height - 540.0) / 2).clamp(30.0, 160.0);

    return Stack(
      children: [
        // Semi-transparent backdrop to dismiss on click outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
        // Floating toolbar card positioned on overlay
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
    final textContent = _selectedTextController.text;
    final isTextEmpty = textContent.trim().isEmpty;
    final wordCount = textContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTextEmpty
                ? const Color(0xFFEF4444).withOpacity(0.7)
                : const Color(0xFF6366F1).withOpacity(0.7),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isTextEmpty
                  ? const Color(0xFFEF4444).withOpacity(0.18)
                  : const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFA5B4FC),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppTranslations.tr('edit_selection', lang),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Full Selected Text (Editable & Scrollable Area) ─────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppTranslations.tr('selected_text_preview', lang).toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        if (!isTextEmpty)
                          TextButton.icon(
                            onPressed: _clearSelectedText,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF87171),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: Text(
                              AppTranslations.tr('clear_selection', lang),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTextEmpty
                                ? Colors.redAccent.withOpacity(0.2)
                                : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isTextEmpty
                                ? (AppTranslations.tr('section_deleted_notice', lang))
                                : '$wordCount ${AppTranslations.tr("words", lang)}',
                            style: GoogleFonts.inter(
                              color: isTextEmpty ? Colors.redAccent : const Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 140, maxHeight: 260),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTextEmpty ? Colors.redAccent.withOpacity(0.5) : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            constraints: const BoxConstraints(minHeight: 140),
                            decoration: BoxDecoration(
                              color: isTextEmpty ? Colors.redAccent : const Color(0xFF818CF8),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: TextField(
                                    controller: _selectedTextController,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    onChanged: (_) => setState(() {}),
                                    style: GoogleFonts.roboto(
                                      color: isTextEmpty ? Colors.redAccent : const Color(0xFFF1F5F9),
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppTranslations.tr('edit_manually_hint', lang),
                                      hintStyle: GoogleFonts.roboto(
                                        color: const Color(0xFF475569),
                                        fontSize: 13,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── AI Instruction Input ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _instructionController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      minLines: 1,
                      onSubmitted: (_) => _handleAISubmit(),
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr('edit_selection_hint', lang),
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  ],
                ),
              ),

              // ── Action Buttons (AI vs Manual Save) ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    // Manual Save / Delete Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleManualSubmit,
                        icon: Icon(
                          isTextEmpty ? Icons.delete_forever_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isTextEmpty
                              ? AppTranslations.tr('delete_and_save', lang)
                              : AppTranslations.tr('save_manual_edit', lang),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isTextEmpty ? const Color(0xFFF87171) : const Color(0xFF34D399),
                          side: BorderSide(
                            color: isTextEmpty ? const Color(0xFFEF4444) : const Color(0xFF059669),
                            width: 1.5,
                          ),
                          backgroundColor: isTextEmpty
                              ? Colors.redAccent.withOpacity(0.1)
                              : const Color(0xFF059669).withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // AI Generate Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleAISubmit,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          AppTranslations.tr('generate_new_version', lang),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
