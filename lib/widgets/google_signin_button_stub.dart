import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Non-web fallback: a plain button triggering the imperative sign-in flow.
Widget buildGoogleSignInButton(
  GoogleSignIn googleSignIn, {
  required void Function(String token) onTokenReceived,
  void Function(String error)? onError,
}) {
  return OutlinedButton.icon(
    onPressed: () async {
      try {
        final account = await googleSignIn.signIn();
        if (account != null) {
          final auth = await account.authentication;
          final token = auth.idToken ?? auth.accessToken;
          if (token != null && token.isNotEmpty) {
            onTokenReceived(token);
          } else {
            onError?.call('Google token alınamadı.');
          }
        }
      } catch (e) {
        onError?.call(e.toString().replaceAll('Exception: ', ''));
      }
    },
    icon: const Icon(Icons.login),
    label: const Text('Google ile giriş yap'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    ),
  );
}
