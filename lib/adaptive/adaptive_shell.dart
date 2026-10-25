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

/// One shell — phone (bottom nav) / tablet·desktop·TV (sidebar).
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

  final _pages = const [
    HomePage(),
    BrowsePage(),
    RadioPage(),
    LibraryPage(),
    SearchPage(),
  ];

  static const _labels = ['Home', 'Browse', 'Radio', 'Library', 'Search'];
  static const _icons = [
    Icons.home_rounded,
    Icons.explore_outlined,
    Icons.podcasts_rounded,
    Icons.library_music_rounded,
    Icons.search_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _collapseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _collapseCtrl.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    // Only collapse bottom nav on phone
    if (!Breakpoints.isCompact(context)) return false;
    final should = n.metrics.pixels > 48;
    if (should != _collapsed) {
      setState(() => _collapsed = should);
      if (should) {
        _collapseCtrl.forward();
      } else {
        _collapseCtrl.reverse();
      }
    }
    return false;
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
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

  // ── Phone: floating bottom nav (existing behaviour) ─────────────────
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
    final t = Curves.easeInOutCubic.transform(_collapseCtrl.value);
    final items = _collapsed ? const [0, 3, 4] : const [0, 1, 2, 3, 4];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 12 + MediaQuery.paddingOf(context).bottom * 0.4),
      child: AnimatedBuilder(
        animation: Listenable.merge([_collapseCtrl, SettingsService.instance]),
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LiquidGlass(
                  borderRadius: BorderRadius.circular(28 - 6 * t),
                  child: SizedBox(
                    height: 64 - 10 * t,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final i
                            in items.where((e) => e != 4 || !_collapsed))
                          _navIcon(i, cs, compact: _collapsed),
                      ],
                    ),
                  ),
                ),
              ),
              if (_collapsed) ...[
                SizedBox(width: 8 + 4 * t),
                Transform.translate(
                  offset: Offset(12 * (1 - t), -6 * t),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * t,
                    child: LiquidGlass(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _navIcon(4, cs, compact: true, bubble: true),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Tablet / Desktop: sidebar ───────────────────────────────────────
  Widget _sideNav({required bool rail, required bool wide}) {
    final cs = Theme.of(context).colorScheme;
    final sideW = rail ? 84.0 : (wide ? 240.0 : 200.0);
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: sideW,
            child: Material(
              color: cs.surfaceContainerLowest,
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(rail ? 12 : 20, 20, 12, 12),
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
                    const SizedBox(height: 8),
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
          VerticalDivider(width: 1, color: cs.outlineVariant.withOpacity(0.35)),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }

  Widget _sideItem(int i, ColorScheme cs, {required bool rail}) {
    final selected = _index == i;
    final child = rail
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icons[i],
                  color: selected ? cs.primary : cs.onSurface.withOpacity(0.5)),
              const SizedBox(height: 4),
              Text(_labels[i],
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.45))),
            ],
          )
        : ListTile(
            leading: Icon(_icons[i],
                color: selected ? cs.primary : cs.onSurface.withOpacity(0.55)),
            title: Text(_labels[i],
                style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withOpacity(0.75))),
            selected: selected,
            selectedTileColor: cs.primary.withOpacity(0.1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => _go(i),
          );

    if (rail) {
      return InkWell(
        onTap: () => _go(i),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: child,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: child,
    );
  }

  // ── TV: large sidebar + D-pad friendly focus ────────────────────────
  Widget _tv() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(
              color: cs.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo/pokke_logo.png',
                            width: 48, height: 48,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.album, size: 48)),
                        const SizedBox(width: 14),
                        Text('Pokke',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 36),
                    for (var i = 0; i < _labels.length; i++)
                      _tvItem(i, cs),
                    const Spacer(),
                    const MiniPlayer(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _pages[_index],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tvItem(int i, ColorScheme cs) {
    final selected = _index == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusableActionDetector(
        onShowFocusHighlight: (_) {},
        child: Material(
          color: selected ? cs.primary.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _go(i),
            focusColor: cs.primary.withOpacity(0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Icon(_icons[i],
                      size: 28,
                      color: selected
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 16),
                  Text(_labels[i],
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.75))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int i, ColorScheme cs,
      {bool compact = false, bool bubble = false}) {
    final selected = _index == i;
    return InkWell(
      onTap: () => _go(i),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: bubble ? 0 : 10, vertical: compact ? 6 : 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[i],
              size: selected ? 26 : 22,
              color: selected ? cs.primary : cs.onSurface.withOpacity(0.45),
            ),
            if (!compact && !bubble) ...[
              const SizedBox(height: 2),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? cs.primary : cs.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
