import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Non-web fallback: a plain button triggering the imperative sign-in flow.
/// Unlike on web, this does return an ID token on native platforms.
Widget buildGoogleSignInButton(GoogleSignIn googleSignIn) {
  return OutlinedButton.icon(
    onPressed: () => googleSignIn.signIn(),
    icon: const Icon(Icons.login),
    label: const Text('Google ile giriş yap'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    ),
  );
}
