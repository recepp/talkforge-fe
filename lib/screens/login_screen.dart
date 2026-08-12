import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';
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
const bool _kGoogleSignInEnabled = true;

class LoginScreen extends StatefulWidget {
  final String? initialErrorMessage;
  const LoginScreen({super.key, this.initialErrorMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  GoogleSignIn? _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialErrorMessage != null && widget.initialErrorMessage!.isNotEmpty) {
      _errorMessage = widget.initialErrorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorMessage.isNotEmpty) {
          _showError(_errorMessage);
        }
      });
    }
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
      try {
        _googleUserSub = googleSignIn.onCurrentUserChanged.listen(
          _onGoogleUserChanged,
          onError: (Object _) {
            if (mounted) setState(() => _googleSignIn = null);
          },
        );
      } catch (e) {
        debugPrint('Google Sign In stream listen error: $e');
      }
      if (mounted) setState(() => _googleSignIn = googleSignIn);
    } catch (e) {
      debugPrint('Google Sign In init error: $e');
      if (mounted) setState(() => _googleSignIn = null);
    }
  }

  Future<void> _onGoogleUserChanged(GoogleSignInAccount? account) async {
    if (account == null) return;
    final auth = await account.authentication;
    final token = auth.idToken ?? auth.accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      final lang = Provider.of<AuthProvider>(context, listen: false).language;
      setState(() => _errorMessage = AppTranslations.tr('google_signin_failed', lang));
      return;
    }
    await _submitGoogleToken(token);
  }

  void _showError(String rawErr) {
    if (!mounted) return;
    final cleanErr = rawErr.replaceAll('Exception: ', '');
    final lang = Provider.of<AuthProvider>(context, listen: false).language;
    final translatedErr = AppTranslations.translateError(cleanErr, lang);

    setState(() {
      _errorMessage = cleanErr;
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  translatedErr,
                  style: GoogleFonts.schibstedGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  Future<void> _submitGoogleToken(String idToken) async {
    setState(() {
      _errorMessage = '';
      _isSubmitting = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loginWithGoogle(idToken);
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
      _isSubmitting = true;
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
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration(String hint, AppColors c) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 14),
      filled: true,
      fillColor: c.surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.bord),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.acc),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.failed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = _isSubmitting || authProvider.isLoading;
    final lang = authProvider.language;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.acc,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: c.acc.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Icon(Icons.record_voice_over, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'TalkForge',
                        style: GoogleFonts.schibstedGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: c.tx,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? AppTranslations.tr('signup_subtitle', lang)
                            : AppTranslations.tr('login_subtitle', lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.schibstedGrotesk(fontSize: 14, color: c.tx2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppTranslations.translateError(_errorMessage, lang),
                              style: GoogleFonts.schibstedGrotesk(
                                color: c.tx,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nicknameController,
                      style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 14),
                      decoration: _fieldDecoration(AppTranslations.tr('nickname_label', lang), c),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? AppTranslations.tr('nickname_required', lang) : null,
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: _emailController,
                    style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration(AppTranslations.tr('email_label', lang), c),
                    validator: (value) {
                      final trimmed = value?.trim();
                      if (trimmed == null || trimmed.isEmpty) return AppTranslations.tr('email_required', lang);
                      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                        return AppTranslations.tr('email_invalid', lang);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordController,
                    style: GoogleFonts.schibstedGrotesk(color: c.tx, fontSize: 14),
                    obscureText: true,
                    decoration: _fieldDecoration(AppTranslations.tr('password_label', lang), c),
                    validator: (value) => value == null || value.length < 4
                        ? AppTranslations.tr('password_short', lang)
                        : null,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.acc,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isSignUp ? AppTranslations.tr('register', lang) : AppTranslations.tr('login', lang),
                            style: GoogleFonts.schibstedGrotesk(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),

                  if (_googleSignIn != null) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: c.bord)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            AppTranslations.tr('or_divider', lang),
                            style: GoogleFonts.schibstedGrotesk(color: c.tx3, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: c.bord)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: buildGoogleSignInButton(
                        _googleSignIn!,
                        onTokenReceived: (token) => _submitGoogleToken(token),
                        onError: (err) {
                          if (mounted) setState(() => _errorMessage = err);
                        },
                      ),
                    ),
                  ],

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = '';
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: c.accTx),
                    child: Text(
                      _isSignUp
                          ? AppTranslations.tr('already_have_account', lang)
                          : AppTranslations.tr('dont_have_account', lang),
                      style: GoogleFonts.schibstedGrotesk(fontSize: 13),
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
