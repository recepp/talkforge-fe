import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../services/api_service.dart';
import 'talk_detail_screen.dart';

class CreateTalkDialog extends StatefulWidget {
  const CreateTalkDialog({super.key});

  @override
  State<CreateTalkDialog> createState() => _CreateTalkDialogState();
}

class _CreateTalkDialogState extends State<CreateTalkDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _initializedLang = false;

  final List<Map<String, String>> _speechTypeItems = [
    {'code': 'speech_type_politician', 'title': 'Siyasetçi Konuşması', 'symbol': '🏛️'},
    {'code': 'speech_type_imam', 'title': 'İmam Vaazı / Hutbe', 'symbol': '🕌'},
    {'code': 'speech_type_teacher_welcome', 'title': 'Öğretmen Sınıfa Tanışma Konuşması', 'symbol': '🎓'},
    {'code': 'speech_type_teacher_farewell', 'title': 'Öğretmen Sınıfa Veda Konuşması', 'symbol': '👋'},
    {'code': 'speech_type_business', 'title': 'Genel İş Sunumu / Hitabet', 'symbol': '💼'},
    {'code': 'speech_type_wedding', 'title': 'Düğün / Kutlama Konuşması', 'symbol': '🥂'},
  ];

  final List<Map<String, String>> _languageItems = [
    {'code': 'Türkçe', 'symbol': '🇹🇷'},
    {'code': 'İngilizce', 'symbol': '🇬🇧'},
    {'code': 'Almanca', 'symbol': '🇩🇪'},
    {'code': 'Fransızca', 'symbol': '🇫🇷'},
    {'code': 'İspanyolca', 'symbol': '🇪🇸'},
    {'code': 'Arapça', 'symbol': '🇸🇦'},
    {'code': 'Rusça', 'symbol': '🇷🇺'},
  ];

  String _selectedLanguage = 'Türkçe';
  String _selectedSpeechType = 'Siyasetçi Konuşması';

  final _placeKey = GlobalKey();
  final _topicKey = GlobalKey();
  final _placeFocusNode = FocusNode();
  final _topicFocusNode = FocusNode();

  final _placeController = TextEditingController();
  final _topicController = TextEditingController();
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
      _initializedLang = true;
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _topicController.dispose();
    _placeFocusNode.dispose();
    _topicFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      if (_placeController.text.trim().isEmpty) {
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
      final newRequest = await ApiService.createTalkRequest(
        mode: 'new',
        language: _selectedLanguage,
        place: _placeController.text.trim(),
        topic: _topicController.text.trim(),
        speechType: _selectedSpeechType,
        duration: _durationMinutes.toInt(),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 800),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334155), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Popup Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF818CF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppTranslations.tr('create_talk_title', lang),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),

            // Dialog Content
            Flexible(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF6366F1)),
                          const SizedBox(height: 24),
                          Text(
                            AppTranslations.tr('generating_loader', lang),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                          )
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
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
                              const SizedBox(height: 20),
                            ],

                            // 1 & 2. Speech Type & Language Dropdowns (Side-by-side for compact, narrow popup width)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 450) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildSpeechTypeDropdown(lang)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildLanguageDropdown(lang)),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildSpeechTypeDropdown(lang),
                                      const SizedBox(height: 16),
                                      _buildLanguageDropdown(lang),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 20),

                            // 3. Place Text Field
                            TextFormField(
                              key: _placeKey,
                              focusNode: _placeFocusNode,
                              controller: _placeController,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: AppTranslations.tr('speech_place', lang),
                                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.place_outlined, color: Color(0xFFF59E0B)),
                                hintText: AppTranslations.tr('speech_place_hint', lang),
                                hintStyle: const TextStyle(color: Color(0xFF475569)),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? AppTranslations.tr('speech_place_required', lang) : null,
                            ),
                            const SizedBox(height: 20),

                            // 4. Duration Slider Card
                            Card(
                              color: const Color(0xFF1E293B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF334155)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppTranslations.tr('speech_duration', lang),
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${_durationMinutes.toInt()} ${AppTranslations.tr('minutes', lang)}',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: const Color(0xFF6366F1),
                                        inactiveTrackColor: const Color(0xFF334155),
                                        thumbColor: const Color(0xFF6366F1),
                                        overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
                                      ),
                                      child: Slider(
                                        value: _durationMinutes,
                                        min: 1.0,
                                        max: 30.0,
                                        divisions: 29,
                                        onChanged: (val) {
                                          setState(() {
                                            _durationMinutes = val;
                                          });
                                        },
                                      ),
                                    ),
                                    Text(
                                      '${AppTranslations.tr('avg_word_count', lang)}: ~${_durationMinutes.toInt() * 130} ${AppTranslations.tr('words', lang)}',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 5. Topic Text Field
                            TextFormField(
                              key: _topicKey,
                              focusNode: _topicFocusNode,
                              controller: _topicController,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              maxLines: 5,
                              decoration: InputDecoration(
                                labelText: AppTranslations.tr('speech_topic', lang),
                                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 80.0),
                                  child: Icon(Icons.edit_note_outlined, color: Color(0xFFF43F5E)),
                                ),
                                hintText: AppTranslations.tr('speech_topic_hint', lang),
                                hintStyle: const TextStyle(color: Color(0xFF475569)),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? AppTranslations.tr('speech_topic_required', lang) : null,
                            ),
                            const SizedBox(height: 28),

                            // Submit Button
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                AppTranslations.tr('generate_talk_button', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildSpeechTypeDropdown(String lang) {
    return DropdownButtonFormField<String>(
      value: _selectedSpeechType,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: const Color(0xFF1E293B),
      menuMaxHeight: 480,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8)),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: AppTranslations.tr('speech_purpose', lang),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: const Icon(Icons.campaign_outlined, color: Color(0xFF818CF8), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
        ),
      ),
      selectedItemBuilder: (context) {
        return _speechTypeItems.map((item) {
          final title = AppTranslations.tr(item['code']!, lang);
          final symbol = item['symbol']!;
          return Row(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        }).toList();
      },
      items: _speechTypeItems.map((item) {
        final title = AppTranslations.tr(item['code']!, lang);
        final symbol = item['symbol']!;
        final isSel = _selectedSpeechType == item['title'];

        return DropdownMenuItem<String>(
          value: item['title'],
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFF6366F1).withOpacity(0.25)
                      : const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? const Color(0xFF818CF8) : const Color(0xFF334155).withOpacity(0.6),
                  ),
                ),
                child: Text(symbol, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSel ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isSel)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF818CF8),
                  size: 16,
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedSpeechType = val;
          });
        }
      },
    );
  }

  Widget _buildLanguageDropdown(String lang) {
    return DropdownButtonFormField<String>(
      value: _selectedLanguage,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: const Color(0xFF1E293B),
      menuMaxHeight: 480,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF34D399)),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: AppTranslations.tr('speech_lang', lang),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: const Icon(Icons.language_outlined, color: Color(0xFF34D399), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
        ),
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
                child: Text(
                  translatedLang,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
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
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFF059669).withOpacity(0.25)
                      : const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? const Color(0xFF34D399) : const Color(0xFF334155).withOpacity(0.6),
                  ),
                ),
                child: Text(symbol, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  translatedLang,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSel ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isSel)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34D399),
                  size: 16,
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedLanguage = val;
          });
        }
      },
    );
  }
}
