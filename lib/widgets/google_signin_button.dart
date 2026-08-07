import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart' as platform;

/// Renders the platform-appropriate "Sign in with Google" control.
///
/// On web, Google Identity Services only returns an ID token through its own
/// rendered button (a custom button + `signIn()` only yields an access
/// token there, which the backend's `idtoken.Validate` cannot use) — so web
/// renders Google's own button. Other platforms use a plain button that
/// triggers the imperative sign-in flow, which does return an ID token.
Widget buildGoogleSignInButton(GoogleSignIn googleSignIn) {
  return platform.buildGoogleSignInButton(googleSignIn);
}
