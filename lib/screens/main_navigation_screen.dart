import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_translations.dart';
import 'talks_screen.dart';
import 'rooms_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TalksScreen(),
    RoomsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: const Color(0xFF6366F1),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.forum_outlined),
              activeIcon: const Icon(Icons.forum),
              label: AppTranslations.tr('my_talks', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.groups_outlined),
              activeIcon: const Icon(Icons.groups),
              label: 'Odalar',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_circle_outlined),
              activeIcon: const Icon(Icons.account_circle),
              label: AppTranslations.tr('my_profile', lang),
            ),
          ],
        ),
      ),
    );
  }
}
