import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web implementation: renders Google's own GIS button. This is required to
/// receive an ID token on web (see google_signin_button.dart for why).
Widget buildGoogleSignInButton(GoogleSignIn googleSignIn) {
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
}
