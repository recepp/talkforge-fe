import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

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
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: ApiService.navigatorKey,
          title: 'TalkForge AI',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isLoading) {
                return Scaffold(
                  backgroundColor: context.colors.bg,
                  body: Center(
                    child: CircularProgressIndicator(color: context.colors.acc),
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
      },
    );
  }
}
