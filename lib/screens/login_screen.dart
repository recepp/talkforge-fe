import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../widgets/google_signin_button.dart';

// Testing (see BE #14 / FE #4 issue comments) found that constructing
// GoogleSignIn on web crashes the whole app to a blank screen in this
// environment when Google's GIS script can't be reached (network policy,
// ad blocker, ...) — the failure happens inside the plugin's own JS interop
// layer and survives try/catch, runZonedGuarded, and deferring past the
// first frame. That test environment couldn't reach google's domains at
// all, so it's unclear whether this reproduces with real network access —
// this needs verifying against a real GOOGLE_CLIENT_ID before enabling.
// Flip this to true only after confirming the login screen stays usable
// even when Google's script fails to load (throttle/block it and reload).
const bool _kGoogleSignInEnabled = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isSignUp = false;
  String _errorMessage = '';

  GoogleSignIn? _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSub;

  @override
  void initState() {
    super.initState();
    if (_kGoogleSignInEnabled && Constants.googleClientId.isNotEmpty) {
      // Deferred past the first frame: constructing GoogleSignIn kicks off
      // Google's GIS script injection immediately, and if that fails
      // (network issue, blocked domain, ad blocker, ...) it can throw
      // before the engine reports its first paint, leaving a blank screen.
      // Waiting for the first frame means the login form is already on
      // screen before this risk is taken.
      WidgetsBinding.instance.addPostFrameCallback((_) => _initGoogleSignIn());
    }
  }

  void _initGoogleSignIn() {
    try {
      final googleSignIn = GoogleSignIn(clientId: Constants.googleClientId);
      _googleUserSub = googleSignIn.onCurrentUserChanged.listen(
        _onGoogleUserChanged,
        onError: (Object _) {
          if (mounted) setState(() => _googleSignIn = null);
        },
      );
      if (mounted) setState(() => _googleSignIn = googleSignIn);
    } catch (_) {
      if (mounted) setState(() => _googleSignIn = null);
    }
  }

  Future<void> _onGoogleUserChanged(GoogleSignInAccount? account) async {
    if (account == null) return;
    final idToken = (await account.authentication).idToken;
    if (idToken == null) {
      setState(() => _errorMessage = 'Google girişi başarısız: kimlik jetonu alınamadı.');
      return;
    }
    await _submitGoogleToken(idToken);
  }

  Future<void> _submitGoogleToken(String idToken) async {
    setState(() => _errorMessage = '');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loginWithGoogle(idToken);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _googleUserSub?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_isSignUp) {
        await authProvider.signup(
          _emailController.text.trim(),
          _passwordController.text,
          _nicknameController.text.trim(),
        );
      } else {
        await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;
    final lang = authProvider.language;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  const Icon(
                    Icons.record_voice_over_outlined,
                    size: 64,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    'TalkForge AI',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? AppTranslations.tr('signup_subtitle', lang)
                        : AppTranslations.tr('login_subtitle', lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 32),

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
                    const SizedBox(height: 16),
                  ],

                  if (_isSignUp) ...[
                    // Nickname Field
                    TextFormField(
                      controller: _nicknameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: AppTranslations.tr('nickname_label', lang),
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
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
                          value == null || value.trim().isEmpty ? AppTranslations.tr('nickname_required', lang) : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppTranslations.tr('email_label', lang),
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppTranslations.tr('email_required', lang);
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return AppTranslations.tr('email_invalid', lang);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.tr('password_label', lang),
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 4
                        ? AppTranslations.tr('password_short', lang)
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? AppTranslations.tr('register', lang) : AppTranslations.tr('login', lang),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  if (_googleSignIn != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF334155))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            AppTranslations.tr('or_divider', lang),
                            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF334155))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(child: buildGoogleSignInButton(_googleSignIn!)),
                  ],

                  const SizedBox(height: 16),

                  // Toggle Button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = '';
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF818CF8),
                    ),
                    child: Text(
                      _isSignUp
                          ? AppTranslations.tr('already_have_account', lang)
                          : AppTranslations.tr('dont_have_account', lang),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
