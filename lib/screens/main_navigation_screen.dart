import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../theme/app_theme.dart';
import 'talks_screen.dart';
import 'rooms_screen.dart';
import 'profile_screen.dart';
import 'invites_screen.dart';

import 'room_detail_screen.dart';
import 'talk_detail_screen.dart';
import '../services/navigation_persistence.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex = NavigationPersistence.initialTabIndexFromUrl();
  int _pendingInviteCount = 0;
  int _unreadRoomCount = 0;
  Timer? _inviteRefreshTimer;
  final _talksKey = GlobalKey<TalksScreenState>();
  final _roomsKey = GlobalKey<RoomsScreenState>();
  final _invitesKey = GlobalKey<InvitesScreenState>();

  late final List<Widget> _screens = [
    TalksScreen(key: _talksKey),
    RoomsScreen(key: _roomsKey),
    InvitesScreen(key: _invitesKey, onInvitesChanged: _onInvitesChanged),
    const ProfileScreen(),
  ];

  void _onInvitesChanged() {
    _loadCounts();
    _roomsKey.currentState?.fetchRooms(showLoading: false);
  }

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _restoreSavedNavigationState();
    // Periodically refresh pending invite and unread room badge count every 15 seconds
    _inviteRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadCounts());
  }

  Future<void> _restoreSavedNavigationState() async {
    final state = await NavigationPersistence.restoreState();
    if (!mounted) return;
    if (state.tabIndex != _currentIndex) {
      setState(() => _currentIndex = state.tabIndex);
    }

    if (state.detailType != null && state.detailId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (state.detailType == 'talk') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TalkDetailScreen(talkNode: {'id': state.detailId!}),
            ),
          ).then((_) {
            NavigationPersistence.saveState(tabIndex: state.tabIndex);
            _loadCounts();
          });
        } else if (state.detailType == 'room') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(roomId: state.detailId!),
            ),
          ).then((_) {
            NavigationPersistence.saveState(tabIndex: state.tabIndex);
            _loadCounts();
            _roomsKey.currentState?.fetchRooms();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _inviteRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final invites = await ApiService.getInvites().catchError((_) => <dynamic>[]);
      final rooms = await ApiService.getRooms().catchError((_) => <dynamic>[]);
      if (mounted) {
        int unreadRooms = 0;
        for (final r in rooms) {
          if (r is Map && (r['has_unread'] == true || (r['unread_count'] ?? 0) > 0)) {
            unreadRooms++;
          }
        }
        setState(() {
          _pendingInviteCount = invites.length;
          _unreadRoomCount = unreadRooms;
        });
      }
    } catch (_) {
      // Silently ignore — the badge simply won't show.
    }
  }

  void _openCreateTalk() => _talksKey.currentState?.openCreateTalkDialog();

  void _goTab(int i) {
    setState(() => _currentIndex = i);
    NavigationPersistence.saveState(tabIndex: i);
    _loadCounts();
    if (i == 1) {
      _roomsKey.currentState?.fetchRooms();
    } else if (i == 2) {
      _invitesKey.currentState?.fetchInvites().then((_) => _loadCounts());
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context); // rebuild on language changes
    final c = context.colors;
    final content = IndexedStack(index: _currentIndex, children: _screens);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: c.bg,
            body: SafeArea(bottom: false, child: content),
            bottomNavigationBar: _MobileBottomNav(
              currentIndex: _currentIndex,
              onTap: _goTab,
              pendingInviteCount: _pendingInviteCount,
              unreadRoomCount: _unreadRoomCount,
            ),
            floatingActionButton: _currentIndex == 0 ? _NewTalkFab(onPressed: _openCreateTalk) : null,
          );
        }

        return Scaffold(
          backgroundColor: c.bg,
          body: Row(
            children: [
              _Sidebar(
                currentIndex: _currentIndex,
                onTap: _goTab,
                onNewTalk: _openCreateTalk,
                pendingInviteCount: _pendingInviteCount,
                unreadRoomCount: _unreadRoomCount,
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.onTap,
    required this.onNewTalk,
    required this.pendingInviteCount,
    required this.unreadRoomCount,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onNewTalk;
  final int pendingInviteCount;
  final int unreadRoomCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = authProvider.language;
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
            label: AppTranslations.tr('my_talks', lang),
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          const SizedBox(height: 4),
          _NavItemBadge(
            icon: Icons.groups_outlined,
            filledIcon: Icons.groups,
            label: AppTranslations.tr('rooms', lang),
            active: currentIndex == 1,
            badgeCount: unreadRoomCount,
            onTap: () => onTap(1),
          ),
          const SizedBox(height: 4),
          _NavItemBadge(
            icon: Icons.mail_outline_rounded,
            filledIcon: Icons.mail_rounded,
            label: AppTranslations.tr('invites', lang),
            active: currentIndex == 2,
            badgeCount: pendingInviteCount,
            onTap: () => onTap(2),
          ),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.account_circle_outlined,
            filledIcon: Icons.account_circle,
            label: AppTranslations.tr('my_profile', lang),
            active: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onNewTalk,
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppTranslations.tr('new_talk', lang),
                  style: GoogleFonts.schibstedGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700)),
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
              onTap: () => onTap(3),
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
                        style: GoogleFonts.schibstedGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w700, color: c.accTx),
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

// ── Standard nav item (no badge) ───────────────────────────────────────────────
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

// ── Nav item with notification badge ──────────────────────────────────────────
class _NavItemBadge extends StatelessWidget {
  const _NavItemBadge({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.active,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool active;
  final int badgeCount;
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(active ? filledIcon : icon, size: 18, color: active ? c.accTx : c.tx3),
                  if (badgeCount > 0)
                    Positioned(
                      top: -5,
                      right: -6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.schibstedGrotesk(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? c.accTx : c.tx3,
                  ),
                ),
              ),
              if (badgeCount > 0 && !active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x22EF4444),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.schibstedGrotesk(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile Bottom Nav ─────────────────────────────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.pendingInviteCount,
    required this.unreadRoomCount,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingInviteCount;
  final int unreadRoomCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = Provider.of<AuthProvider>(context).language;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surf, border: Border(top: BorderSide(color: c.bordSoft))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _MobileNavItem(
              icon: Icons.forum_outlined,
              filledIcon: Icons.forum,
              label: AppTranslations.tr('my_talks', lang),
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _MobileNavItemBadge(
              icon: Icons.groups_outlined,
              filledIcon: Icons.groups,
              label: AppTranslations.tr('rooms', lang),
              active: currentIndex == 1,
              badgeCount: unreadRoomCount,
              onTap: () => onTap(1),
            ),
            _MobileNavItemBadge(
              icon: Icons.mail_outline_rounded,
              filledIcon: Icons.mail_rounded,
              label: AppTranslations.tr('invites', lang),
              active: currentIndex == 2,
              badgeCount: pendingInviteCount,
              onTap: () => onTap(2),
            ),
            _MobileNavItem(
              icon: Icons.account_circle_outlined,
              filledIcon: Icons.account_circle,
              label: AppTranslations.tr('my_profile', lang),
              active: currentIndex == 3,
              onTap: () => onTap(3),
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

class _MobileNavItemBadge extends StatelessWidget {
  const _MobileNavItemBadge({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.active,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool active;
  final int badgeCount;
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(active ? filledIcon : icon, size: 23, color: active ? c.acc : c.tx3),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
    final lang = Provider.of<AuthProvider>(context).language;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: c.acc.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 20),
        label: Text(AppTranslations.tr('new_talk', lang),
            style: GoogleFonts.schibstedGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700)),
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
