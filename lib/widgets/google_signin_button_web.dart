import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web implementation: renders Google's own GIS button. This is required to
/// receive an ID token on web (see google_signin_button.dart for why).
/// Web implementation: renders Google's own GIS button safely.
/// In web release mode, JS interop / minified cast issues or network blocks
/// can throw inside `web.renderButton`. We catch those errors so the login
/// screen never crashes to a blank grey screen.
Widget buildGoogleSignInButton(
  GoogleSignIn googleSignIn, {
  required void Function(String token) onTokenReceived,
  void Function(String error)? onError,
}) {
  return GoogleSignInButtonWeb(
    googleSignIn: googleSignIn,
    onTokenReceived: onTokenReceived,
    onError: onError,
  );
}

class GoogleSignInButtonWeb extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final void Function(String token) onTokenReceived;
  final void Function(String error)? onError;

  const GoogleSignInButtonWeb({
    super.key,
    required this.googleSignIn,
    required this.onTokenReceived,
    this.onError,
  });

  @override
  State<GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<GoogleSignInButtonWeb> {
  bool _hasError = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasError) {
      try {
        return SizedBox(
          height: 44,
          child: web.renderButton(
            configuration: web.GSIButtonConfiguration(
              theme: web.GSIButtonTheme.filledBlack,
              size: web.GSIButtonSize.large,
              shape: web.GSIButtonShape.pill,
              text: web.GSIButtonText.signinWith,
            ),
          ),
        );
      } catch (e, stack) {
        debugPrint('Google Sign-In web button render error: $e\n$stack');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hasError = true);
        });
        return _buildFallbackButton();
      }
    }

    return _buildFallbackButton();
  }

  Widget _buildFallbackButton() {
    return Container(
      height: 44,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleCustomSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF131314),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF424242)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://developers.google.com/static/identity/images/g-logo.png',
                    height: 18,
                    width: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Google ile Giriş Yap',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleCustomSignIn() async {
    setState(() => _isLoading = true);
    try {
      final account = await widget.googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        final token = auth.idToken ?? auth.accessToken;
        if (token != null && token.isNotEmpty) {
          widget.onTokenReceived(token);
        } else {
          widget.onError?.call('Google token alırken bir hata oluştu.');
        }
      }
    } catch (e) {
      debugPrint('Custom Google sign-in error: $e');
      widget.onError?.call(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}


