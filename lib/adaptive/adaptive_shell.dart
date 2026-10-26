import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/pages/home_page.dart';
import 'package:pokke/pages/browse_page.dart';
import 'package:pokke/pages/radio_page.dart';
import 'package:pokke/pages/library_page.dart';
import 'package:pokke/pages/search_page.dart';
import 'package:pokke/widgets/liquid_glass.dart';
import 'package:pokke/widgets/mini_player.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/widgets/player_route.dart';
import 'package:pokke/screens/settings_screen.dart';
import 'package:pokke/screens/profile_screen.dart';
import 'package:pokke/widgets/tv_side_panel.dart';
import 'package:pokke/screens/chat_list_screen.dart';
import 'package:pokke/screens/friends_map_screen.dart';
import 'package:pokke/screens/listen_together_screen.dart';

/// One shell — phone (bottom nav) / tablet·desktop·TV (sidebar / lean-back).
class AdaptiveShell extends StatefulWidget {
  final bool guest;
  const AdaptiveShell({super.key, this.guest = false});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell>
    with TickerProviderStateMixin {
  int _index = 0;
  bool _collapsed = false;
  late final AnimationController _collapseCtrl;
  late final AnimationController _searchDetachCtrl;

  // Phone: Home, Browse, [Chat if beta], Library, Search — no Radio
  List<Widget> get _pages {
    final chat = SettingsService.instance.flag('private_chat');
    return [
      const HomePage(),
      const BrowsePage(),
      if (chat) const ChatListScreen(),
      const LibraryPage(),
      const SearchPage(),
    ];
  }

  List<String> get _labels {
    final chat = SettingsService.instance.flag('private_chat');
    return [
      'Home',
      'Browse',
      if (chat) 'Chat',
      'Library',
      'Search',
    ];
  }

  List<IconData> get _icons {
    final chat = SettingsService.instance.flag('private_chat');
    return [
      Icons.home_rounded,
      Icons.explore_outlined,
      if (chat) Icons.chat_bubble_outline_rounded,
      Icons.library_music_rounded,
      Icons.search_rounded,
    ];
  }

  // TV simplified: Home / Search / Library
  static const _tvLabels = ['Home', 'Search', 'Your Library'];
  static const _tvIcons = [
    Icons.home_outlined,
    Icons.search_rounded,
    Icons.library_music_outlined,
  ];
  // Map TV tabs to page indices in dynamic list without chat: 0,3,2 — with chat: 0,4,3
  List<int> get _tvPageIdx {
    final chat = SettingsService.instance.flag('private_chat');
    // pages: Home, Browse, [Chat?], Library, Search
    // TV wants Home / Search / Library
    if (chat) return [0, 4, 3]; // Home, Search, Library
    return [0, 3, 2]; // Home, Search, Library
  }

  @override
  void initState() {
    super.initState();
    _collapseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _searchDetachCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    DevicesService.instance.refresh();
  }

  @override
  void dispose() {
    _collapseCtrl.dispose();
    _searchDetachCtrl.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (!Breakpoints.isCompact(context)) return false;
    final should = n.metrics.pixels > 56;
    if (should != _collapsed) {
      setState(() => _collapsed = should);
      if (should) {
        _collapseCtrl.forward();
        Future.delayed(const Duration(milliseconds: 90), () {
          if (mounted && _collapsed) _searchDetachCtrl.forward();
        });
      } else {
        _searchDetachCtrl.reverse();
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted && !_collapsed) _collapseCtrl.reverse();
        });
      }
    }
    return false;
  }

  void _clampIndex() {
    final max = _pages.length - 1;
    if (_index > max) setState(() => _index = max.clamp(0, max));
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendsMapScreen()),
    );
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    _clampIndex();
    final form = Breakpoints.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: switch (form) {
        PokkeFormFactor.phone => _phone(),
        PokkeFormFactor.tablet => _sideNav(rail: true, wide: false),
        PokkeFormFactor.desktop => _sideNav(rail: false, wide: true),
        PokkeFormFactor.tv => _tv(),
      },
    );
  }

  // ── Phone ──────────────────────────────────────────────────────────
  Widget _phone() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _pages[_index]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                _phoneNav(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneNav(ColorScheme cs) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_collapseCtrl, _searchDetachCtrl, SettingsService.instance]),
      builder: (context, _) {
        final t = Curves.easeInOutCubicEmphasized.transform(_collapseCtrl.value);
        final s = Curves.easeOutBack.transform(_searchDetachCtrl.value);
        // Main pill items when collapsed: Home + Library
        final settings = SettingsService.instance;
        final mainItems = _collapsed ? const [0, 3] : const [0, 1, 2, 3, 4];
        final showChat = settings.flag('private_chat');
        final showMap = settings.flag('friends_map');

        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 10 + MediaQuery.paddingOf(context).bottom * 0.35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LiquidGlass(
                  borderRadius: BorderRadius.circular(28 - 8 * t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: 64 - 14 * t,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final i in mainItems)
                          if (!(i == 4 && _collapsed))
                            _navIcon(i, cs, compact: _collapsed),
                      ],
                    ),
                  ),
                ),
              ),
              // Search bubble detaches with liquid motion
              if (_collapsed) ...[
                SizedBox(width: 6 + 10 * s),
                Transform.translate(
                  offset: Offset(28 * (1 - s), -10 * s + 4 * (1 - s)),
                  child: Transform.rotate(
                    angle: 0.12 * (1 - s),
                    child: Transform.scale(
                      scale: 0.72 + 0.28 * s,
                      child: Opacity(
                        opacity: s.clamp(0.0, 1.0),
                        child: LiquidGlass(
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: _navIcon(4, cs, compact: true, bubble: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _navIcon(int i, ColorScheme cs,
      {bool compact = false, bool bubble = false}) {
    final selected = _index == i;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _go(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: Icon(
                _icons[i],
                size: bubble ? 26 : (compact ? 22 : 24),
                color: selected
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.55),
              ),
            ),
            if (!compact && !bubble) ...[
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.5),
                ),
                child: Text(_labels[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tablet / Desktop sidebar ───────────────────────────────────────
  Widget _sideNav({required bool rail, required bool wide}) {
    final cs = Theme.of(context).colorScheme;
    final sideW = rail ? 84.0 : (wide ? 240.0 : 200.0);
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: sideW,
            child: Material(
              color: cs.surfaceContainerLowest,
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.fromLTRB(rail ? 12 : 20, 20, 12, 12),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/logo/pokke_logo.png',
                            width: 36,
                            height: 36,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.album, color: cs.primary),
                          ),
                          if (!rail) ...[
                            const SizedBox(width: 12),
                            Text('Pokke',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: cs.onSurface)),
                          ],
                        ],
                      ),
                    ),
                    for (var i = 0; i < _labels.length; i++)
                      _sideItem(i, cs, rail: rail),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: MiniPlayer(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }

  Widget _sideItem(int i, ColorScheme cs, {required bool rail}) {
    final selected = _index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? cs.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(i),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: rail ? 8 : 16, vertical: 12),
            child: Row(
              children: [
                Icon(_icons[i],
                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.6)),
                if (!rail) ...[
                  const SizedBox(width: 14),
                  Text(_labels[i],
                      style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.75))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TV lean-back (Spotify TV style) ────────────────────────────────
  Widget _tv() {
    final cs = Theme.of(context).colorScheme;
    final pc = PlayerController.instance;
    final tvIndex = _tvPageIdx.indexOf(_index);
    final safeTv = tvIndex < 0 ? 0 : tvIndex;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Top chrome
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
              child: Row(
                children: [
                  // Now playing chip
                  AnimatedBuilder(
                    animation: pc,
                    builder: (_, __) {
                      final song = pc.current;
                      if (song == null) {
                        return const SizedBox(width: 200);
                      }
                      final cover = song['cover_url']?.toString();
                      return Material(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).push(
                            PlayerSlideRoute(
                                page: const MusicPlayerPage(tvMode: true)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: cover != null &&
                                            cover.startsWith('http')
                                        ? Image.network(cover,
                                            fit: BoxFit.cover)
                                        : const ColoredBox(
                                            color: Colors.white12,
                                            child: Icon(Icons.music_note,
                                                size: 18, color: Colors.white70),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 180),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song['title']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        song['artist']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.55),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  pc.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  for (var i = 0; i < _tvLabels.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _tvTab(i, safeTv == i, cs),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => openTvSettings(context),
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () => openTvProfile(context),
                    icon: const Icon(Icons.account_circle_outlined,
                        color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _pages[_tvPageIdx[safeTv]],
          ),
        ],
      ),
    );
  }

  Widget _tvTab(int i, bool selected, ColorScheme cs) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _go(_tvPageIdx[i]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(_tvIcons[i],
                size: 20,
                color: selected ? Colors.white : Colors.white54),
            const SizedBox(width: 8),
            Text(_tvLabels[i],
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
