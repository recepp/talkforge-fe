import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
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
  final _talksKey = GlobalKey<TalksScreenState>();

  late final List<Widget> _screens = [
    TalksScreen(key: _talksKey),
    const RoomsScreen(),
    const ProfileScreen(),
  ];

  void _openCreateTalk() => _talksKey.currentState?.openCreateTalkDialog();

  void _goTab(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = IndexedStack(index: _currentIndex, children: _screens);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: c.bg,
            body: SafeArea(bottom: false, child: content),
            bottomNavigationBar: _MobileBottomNav(currentIndex: _currentIndex, onTap: _goTab),
            floatingActionButton: _currentIndex == 0 ? _NewTalkFab(onPressed: _openCreateTalk) : null,
          );
        }

        return Scaffold(
          backgroundColor: c.bg,
          body: Row(
            children: [
              _Sidebar(currentIndex: _currentIndex, onTap: _goTab, onNewTalk: _openCreateTalk),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentIndex, required this.onTap, required this.onNewTalk});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onNewTalk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authProvider = Provider.of<AuthProvider>(context);
    final nickname = authProvider.nickname ?? '';

    return Container(
      width: 232,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: c.bordSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.record_voice_over, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  'TalkForge',
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.tx,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _NavItem(
            icon: Icons.forum_outlined,
            filledIcon: Icons.forum,
            label: 'Konuşmalarım',
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.groups_outlined,
            filledIcon: Icons.groups,
            label: 'Odalar',
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.account_circle_outlined,
            filledIcon: Icons.account_circle,
            label: 'Profil',
            active: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onNewTalk,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Yeni Konuşma', style: GoogleFonts.schibstedGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.acc,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onTap(2),
              hoverColor: c.accSoft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: c.accSoft,
                      child: Text(
                        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                        style: GoogleFonts.schibstedGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: c.accTx),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        nickname,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.schibstedGrotesk(fontSize: 12.5, color: c.tx2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.accSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        hoverColor: c.accSoft.withValues(alpha: active ? 1 : 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(active ? filledIcon : icon, size: 18, color: active ? c.accTx : c.tx3),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.accTx : c.tx3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surf, border: Border(top: BorderSide(color: c.bordSoft))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _MobileNavItem(
              icon: Icons.forum_outlined,
              filledIcon: Icons.forum,
              label: 'Konuşmalar',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _MobileNavItem(
              icon: Icons.groups_outlined,
              filledIcon: Icons.groups,
              label: 'Odalar',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _MobileNavItem(
              icon: Icons.account_circle_outlined,
              filledIcon: Icons.account_circle,
              label: 'Profil',
              active: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? filledIcon : icon, size: 23, color: active ? c.acc : c.tx3),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.schibstedGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? c.acc : c.tx3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTalkFab extends StatelessWidget {
  const _NewTalkFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: c.acc.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 20),
        label: Text('Yeni Konuşma', style: GoogleFonts.schibstedGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: c.acc,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
