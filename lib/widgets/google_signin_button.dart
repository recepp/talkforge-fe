import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart' as platform;

/// Renders the platform-appropriate "Sign in with Google" control.
///
/// On web, Google Identity Services only returns an ID token through its own
/// rendered button (a custom button + `signIn()` yields an access token or ID
/// token depending on config) — web renders Google's own button or a fallback
/// button wired to submit the token.
Widget buildGoogleSignInButton(
  GoogleSignIn googleSignIn, {
  required void Function(String token) onTokenReceived,
  void Function(String error)? onError,
}) {
  return platform.buildGoogleSignInButton(
    googleSignIn,
    onTokenReceived: onTokenReceived,
    onError: onError,
  );
}

