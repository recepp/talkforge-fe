import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_service.dart';

import 'constants.dart';

void main() {
  // Third-party plugins (e.g. Google Sign-In's web JS interop) can throw
  // outside the widget build/layout/paint phases, as unhandled Future
  // errors. Left uncaught, those propagate to the zone and can take down
  // the whole app instead of just the feature that failed. Catch them here
  // so a single misbehaving integration degrades instead of blanking the
  // screen for everyone.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Constants.loadConfig();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const TalkForgeApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

class TalkForgeApp extends StatelessWidget {
  const TalkForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService.navigatorKey,
      title: 'TalkForge AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
          background: const Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            );
          }
          if (authProvider.isAuthenticated) {
            return const MainNavigationScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
