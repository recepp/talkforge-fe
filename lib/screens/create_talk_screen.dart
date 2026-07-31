import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class CreateTalkScreen extends StatefulWidget {
  const CreateTalkScreen({super.key});

  @override
  State<CreateTalkScreen> createState() => _CreateTalkScreenState();
}

class _CreateTalkScreenState extends State<CreateTalkScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final List<String> _languages = ['Türkçe', 'İngilizce', 'Almanca', 'Fransızca', 'Arapça', 'Rusça'];
  final List<String> _speechTypes = [
    'Siyasetçi Konuşması',
    'İmam Vaazı / Hutbe',
    'Öğretmen Sınıfa Tanışma Konuşması',
    'Öğretmen Sınıfa Veda Konuşması',
    'Genel İş Sunumu / Hitabet',
    'Düğün / Kutlama Konuşması'
  ];

  String _selectedLanguage = 'Türkçe';
  String _selectedSpeechType = 'Siyasetçi Konuşması';
  final _placeController = TextEditingController();
  final _topicController = TextEditingController();
  double _durationMinutes = 5.0;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _placeController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await ApiService.createTalkRequest(
        mode: 'new',
        language: _selectedLanguage,
        place: _placeController.text.trim(),
        topic: _topicController.text.trim(),
        speechType: _selectedSpeechType,
        duration: _durationMinutes.toInt(),
      );
      if (mounted) {
        Navigator.pop(context, true); // Returns true to trigger refresh
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Yeni Konuşma Hazırla',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6366F1)),
                  SizedBox(height: 24),
                  Text(
                    'AI konuşma metninizi hazırlıyor...\nLütfen pencereyi kapatmayın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
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

                    // Speech Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSpeechType,
                      style: GoogleFonts.inter(color: Colors.white),
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: InputDecoration(
                        labelText: 'Konuşma Amacı / Rolü',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.campaign_outlined, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                      items: _speechTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSpeechType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Language Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      style: GoogleFonts.inter(color: Colors.white),
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: InputDecoration(
                        labelText: 'Konuşma Dili',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.language_outlined, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                      items: _languages
                          .map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedLanguage = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Place Text Field
                    TextFormField(
                      controller: _placeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Konuşma Yapılacak Yer / Ortam',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.place_outlined, color: Color(0xFF64748B)),
                        hintText: 'Örn: Belediye Konferans Salonu, Merkez Camii, Sınıf 3-A',
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Konuşma yeri giriniz' : null,
                    ),
                    const SizedBox(height: 24),

                    // Duration Slider
                    Card(
                      color: const Color(0xFF1E293B),
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
                                Text(
                                  'Konuşma Süresi',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_durationMinutes.toInt()} Dakika',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _durationMinutes,
                              min: 1.0,
                              max: 30.0,
                              divisions: 29,
                              activeColor: const Color(0xFF6366F1),
                              inactiveColor: const Color(0xFF334155),
                              onChanged: (val) {
                                setState(() {
                                  _durationMinutes = val;
                                });
                              },
                            ),
                            Text(
                              'Ortalama Metin Boyutu: ~${_durationMinutes.toInt() * 130} kelime',
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

                    // Topic Text Field
                    TextFormField(
                      controller: _topicController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Konuşma Konusu / Detaylar',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        alignLabelWithHint: true,
                        hintText: 'Konuşmada hangi başlıklar yer almalı? Hangi mesajlar verilmeli?',
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Konuşma detaylarını giriniz' : null,
                    ),
                    const SizedBox(height: 32),

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
                        'Konuşma Metnini Hazırla',
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
    );
  }
}
