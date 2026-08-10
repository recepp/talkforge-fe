import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/searchable_talk_type_dropdown.dart';
import 'talk_detail_screen.dart';

class CreateTalkDialog extends StatefulWidget {
  const CreateTalkDialog({super.key, this.roomId});

  /// When set, the created talk is attached to this room instead of being
  /// personal (requires the caller to already be a writer member — the
  /// backend re-validates this regardless).
  final int? roomId;

  @override
  State<CreateTalkDialog> createState() => _CreateTalkDialogState();
}

class _CreateTalkDialogState extends State<CreateTalkDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _initializedLang = false;

  List<Map<String, dynamic>> _talkTypeItems = [];
  Map<String, dynamic>? _selectedTalkType;
  bool _loadingTalkTypes = true;

  List<Map<String, String>> get _languageItems => AppTranslations.supportedLanguages;

  String _selectedLanguage = 'Türkçe';

  final _placeKey = GlobalKey();
  final _topicKey = GlobalKey();
  final _customSpeechTypeKey = GlobalKey();

  final _placeFocusNode = FocusNode();
  final _topicFocusNode = FocusNode();
  final _customSpeechTypeFocusNode = FocusNode();

  final _placeController = TextEditingController();
  final _topicController = TextEditingController();
  final _customSpeechTypeController = TextEditingController();
  double _durationMinutes = 5.0;

  bool _isLoading = false;
  String _errorMessage = '';

  static String _getLangNameFromCode(String code) {
    switch (code) {
      case 'en': return 'İngilizce';
      case 'de': return 'Almanca';
      case 'fr': return 'Fransızca';
      case 'es': return 'İspanyolca';
      case 'ar': return 'Arapça';
      case 'ru': return 'Rusça';
      default: return 'Türkçe';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedLang) {
      final userLangCode = Provider.of<AuthProvider>(context, listen: false).language;
      _selectedLanguage = _getLangNameFromCode(userLangCode);
      _fetchTalkTypes(userLangCode);
      _initializedLang = true;
    }
  }

  Future<void> _fetchTalkTypes(String langCode) async {
    setState(() {
      _loadingTalkTypes = true;
    });

    try {
      final result = await ApiService.getTalkTypes(langCode: langCode);
      if (mounted) {
        setState(() {
          _talkTypeItems = List<Map<String, dynamic>>.from(result);
          if (_talkTypeItems.isNotEmpty) {
            _selectedTalkType = _talkTypeItems.first;
          }
          _loadingTalkTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingTalkTypes = false;
          _errorMessage = '${AppTranslations.tr('load_talk_types_failed', langCode)}: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _topicController.dispose();
    _customSpeechTypeController.dispose();
    _placeFocusNode.dispose();
    _topicFocusNode.dispose();
    _customSpeechTypeFocusNode.dispose();
    super.dispose();
  }

  bool get _isCustomSelected {
    if (_selectedTalkType == null) return false;
    return _selectedTalkType!['is_custom'] == true || _selectedTalkType!['key'] == 'other';
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      if (_isCustomSelected && _customSpeechTypeController.text.trim().isEmpty) {
        if (_customSpeechTypeKey.currentContext != null) {
          Scrollable.ensureVisible(
            _customSpeechTypeKey.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
        _customSpeechTypeFocusNode.requestFocus();
      } else if (_placeController.text.trim().isEmpty) {
        if (_placeKey.currentContext != null) {
          Scrollable.ensureVisible(
            _placeKey.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
        _placeFocusNode.requestFocus();
      } else if (_topicController.text.trim().isEmpty) {
        if (_topicKey.currentContext != null) {
          Scrollable.ensureVisible(
            _topicKey.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
        _topicFocusNode.requestFocus();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final speechTypeKey = _selectedTalkType?['key'] ?? 'other';
      final customPromptText = _isCustomSelected
          ? _customSpeechTypeController.text.trim()
          : null;

      final newRequest = await ApiService.createTalkRequest(
        mode: 'new',
        language: _selectedLanguage,
        place: _placeController.text.trim(),
        topic: _topicController.text.trim(),
        speechType: speechTypeKey,
        customSpeechType: customPromptText,
        duration: _durationMinutes.toInt(),
        roomId: widget.roomId,
      );

      if (mounted) {
        Navigator.pop(context); // Close popup dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TalkDetailScreen(talkNode: newRequest),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _fieldLabel(String text, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: GoogleFonts.schibstedGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: c.tx2)),
    );
  }

  InputDecoration _flatDecoration(String hint, AppColors c) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 13.5),
      filled: true,
      fillColor: c.surf2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: c.bord),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: c.acc),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.failed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
    final c = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 840),
        decoration: BoxDecoration(
          color: c.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.bord),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 50, offset: const Offset(0, 20))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.tr('create_talk_title', lang),
                    style: GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w700, color: c.tx, fontSize: 18, letterSpacing: -0.2),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(Icons.close, color: c.tx3, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: c.acc),
                          const SizedBox(height: 24),
                          Text(
                            AppTranslations.tr('generating_loader', lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.schibstedGrotesk(color: c.tx2, fontSize: 15),
                          )
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.failed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.failed.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: GoogleFonts.schibstedGrotesk(color: AppColors.dangerTx, fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Konuşma amacı — Searchable Dropdown
                            _fieldLabel(AppTranslations.tr('speech_purpose', lang), c),
                            SearchableTalkTypeDropdown(
                              items: _talkTypeItems,
                              selectedItem: _selectedTalkType,
                              isLoading: _loadingTalkTypes,
                              langCode: lang,
                              onChanged: (item) {
                                setState(() {
                                  _selectedTalkType = item;
                                });
                              },
                            ),
                            const SizedBox(height: 18),

                            if (_isCustomSelected) ...[
                              _fieldLabel(AppTranslations.tr('custom_speech_purpose', lang), c),
                              TextFormField(
                                key: _customSpeechTypeKey,
                                focusNode: _customSpeechTypeFocusNode,
                                controller: _customSpeechTypeController,
                                style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5),
                                decoration: _flatDecoration(AppTranslations.tr('custom_speech_purpose_hint', lang), c),
                                validator: (value) =>
                                    _isCustomSelected && (value == null || value.trim().isEmpty)
                                        ? AppTranslations.tr('custom_speech_purpose_required', lang)
                                        : null,
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Dil + Süre — 2 columns
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 420;
                                final langCol = Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(AppTranslations.tr('speech_lang', lang), c),
                                      _buildLanguageDropdown(lang, c),
                                    ],
                                  ),
                                );
                                final durationCol = Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(
                                        '${AppTranslations.tr('speech_duration', lang)} · ${_durationMinutes.toInt()} ${AppTranslations.tr('minutes', lang)}',
                                        c,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: c.surf2,
                                          border: Border.all(color: c.bord),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: c.acc,
                                            inactiveTrackColor: c.bord,
                                            thumbColor: c.acc,
                                            overlayColor: c.acc.withValues(alpha: 0.2),
                                          ),
                                          child: Slider(
                                            value: _durationMinutes.clamp(1.0, 10.0),
                                            min: 1.0,
                                            max: 10.0,
                                            divisions: 9,
                                            onChanged: (val) => setState(() => _durationMinutes = val),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (narrow) {
                                  return Column(children: [langCol, const SizedBox(height: 16), durationCol]);
                                }
                                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [langCol, const SizedBox(width: 12), durationCol]);
                              },
                            ),
                            const SizedBox(height: 18),

                            _fieldLabel(AppTranslations.tr('speech_place', lang), c),
                            TextFormField(
                              key: _placeKey,
                              focusNode: _placeFocusNode,
                              controller: _placeController,
                              style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5),
                              decoration: _flatDecoration(AppTranslations.tr('speech_place_hint', lang), c),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? AppTranslations.tr('speech_place_required', lang) : null,
                            ),
                            const SizedBox(height: 18),

                            _fieldLabel(AppTranslations.tr('speech_topic', lang), c),
                            TextFormField(
                              key: _topicKey,
                              focusNode: _topicFocusNode,
                              controller: _topicController,
                              style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5),
                              maxLines: 5,
                              minLines: 4,
                              onChanged: (_) => setState(() {}),
                              decoration: _flatDecoration(AppTranslations.tr('speech_topic_hint', lang), c),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? AppTranslations.tr('speech_topic_required', lang) : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${AppTranslations.tr('avg_word_count', lang)}: ~${_durationMinutes.toInt() * 130} ${AppTranslations.tr('words', lang)}',
                              style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 11),
                            ),
                            const SizedBox(height: 22),

                            ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                              label: Text(
                                AppTranslations.tr('generate_talk_button', lang),
                                style: GoogleFonts.schibstedGrotesk(fontSize: 14.5, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.acc,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(String lang, AppColors c) {
    return DropdownButtonFormField<String>(
      value: _selectedLanguage,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: c.surf,
      menuMaxHeight: 420,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.tx3),
      style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        filled: true,
        fillColor: c.surf2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.acc)),
      ),
      selectedItemBuilder: (context) {
        return _languageItems.map((item) {
          final code = item['code']!;
          final symbol = item['symbol']!;
          final translatedLang = AppTranslations.translateLanguageName(code, lang);
          return Row(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(translatedLang, overflow: TextOverflow.ellipsis, style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        }).toList();
      },
      items: _languageItems.map((item) {
        final code = item['code']!;
        final symbol = item['symbol']!;
        final translatedLang = AppTranslations.translateLanguageName(code, lang);
        final isSel = _selectedLanguage == code;

        return DropdownMenuItem<String>(
          value: code,
          child: Row(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  translatedLang,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.schibstedGrotesk(
                    color: isSel ? c.tx : c.tx2,
                    fontSize: 13.5,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSel) Icon(Icons.check_circle_rounded, color: c.accTx, size: 16),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedLanguage = val;
            _fetchTalkTypes(_getLangCodeFromName(val));
          });
        }
      },
    );
  }

  static String _getLangCodeFromName(String name) {
    switch (name) {
      case 'İngilizce': return 'en';
      case 'Almanca': return 'de';
      case 'Fransızca': return 'fr';
      case 'İspanyolca': return 'es';
      case 'Arapça': return 'ar';
      case 'Rusça': return 'ru';
      default: return 'tr';
    }
  }
}
