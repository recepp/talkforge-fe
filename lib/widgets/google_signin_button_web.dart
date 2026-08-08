import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web implementation: renders Google's own GIS button. This is required to
/// receive an ID token on web (see google_signin_button.dart for why).
/// Web implementation: renders Google's own GIS button safely.
/// In web release mode, JS interop / minified cast issues or network blocks
/// can throw inside `web.renderButton`. We catch those errors so the login
/// screen never crashes to a blank grey screen.
Widget buildGoogleSignInButton(GoogleSignIn googleSignIn) {
  return GoogleSignInButtonWeb(googleSignIn: googleSignIn);
}

class GoogleSignInButtonWeb extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  const GoogleSignInButtonWeb({super.key, required this.googleSignIn});

  @override
  State<GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<GoogleSignInButtonWeb> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }
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
      return const SizedBox.shrink();
    }
  }
}

