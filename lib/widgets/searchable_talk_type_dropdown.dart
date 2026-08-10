import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';

class SearchableTalkTypeDropdown extends StatelessWidget {
  const SearchableTalkTypeDropdown({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.langCode,
    this.isLoading = false,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? selectedItem;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String langCode;
  final bool isLoading;

  void _openSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _TalkTypeSearchDialog(
          items: items,
          selectedItem: selectedItem,
          onSelected: (item) {
            onChanged(item);
            Navigator.of(dialogContext).pop();
          },
          langCode: langCode,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (isLoading) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: c.surf2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.bord),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.acc),
          ),
        ),
      );
    }

    final symbol = selectedItem?['symbol'] ?? '💬';
    final title = selectedItem?['title'] ?? selectedItem?['key'] ?? '';

    return InkWell(
      onTap: items.isEmpty ? null : () => _openSearchDialog(context),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surf2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.bord),
        ),
        child: Row(
          children: [
            Text(symbol, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.isNotEmpty ? title : AppTranslations.tr('speech_purpose', langCode),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.schibstedGrotesk(
                  color: title.isNotEmpty ? c.tx : c.tx3,
                  fontSize: 13.5,
                  fontWeight: title.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: c.tx3, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TalkTypeSearchDialog extends StatefulWidget {
  const _TalkTypeSearchDialog({
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.langCode,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? selectedItem;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final String langCode;

  @override
  State<_TalkTypeSearchDialog> createState() => _TalkTypeSearchDialogState();
}

class _TalkTypeSearchDialogState extends State<_TalkTypeSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_query.trim().isEmpty) {
      return widget.items;
    }
    final q = _query.trim().toLowerCase();
    return widget.items.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final key = (item['key'] ?? '').toString().toLowerCase();
      return title.contains(q) || key.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _filteredItems;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        decoration: BoxDecoration(
          color: c.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.bord),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5),
                      onChanged: (val) => setState(() => _query = val),
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr('search_talk_type_hint', widget.langCode),
                        hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: c.tx3, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: c.tx3, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: c.surf2,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.bord),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.acc),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.close_rounded, color: c.tx3, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Items List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          AppTranslations.tr('no_results_found', widget.langCode),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final symbol = item['symbol'] ?? '💬';
                        final title = item['title'] ?? item['key'] ?? '';
                        final isSel = widget.selectedItem?['key'] == item['key'];

                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? c.accSoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? c.acc.withValues(alpha: 0.5) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(symbol, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.schibstedGrotesk(
                                      color: isSel ? c.accTx : c.tx,
                                      fontSize: 13.5,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSel)
                                  Icon(Icons.check_circle_rounded, color: c.acc, size: 18),
                              ],
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
}
