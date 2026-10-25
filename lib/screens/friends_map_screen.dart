import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pokke/services/settings_service.dart';

/// Beta · friends map (privacy + battery + listen stats).
/// 3D-style perspective plane; real GPS/presence comes next via Realtime.
class FriendsMapScreen extends StatefulWidget {
  const FriendsMapScreen({super.key});
  @override
  State<FriendsMapScreen> createState() => _FriendsMapScreenState();
}

class _FriendsMapScreenState extends State<FriendsMapScreen> {
  /// private | friends | best_friends
  String _privacy = 'best_friends';

  final _friends = [
    _Friend('Aya', 0.32, 0.28, 78, 142, 'From The Start', 3.2),
    _Friend('Leo', 0.62, 0.42, 54, 89, 'Too Little, Too Late', 1.1),
    _Friend('Mika', 0.45, 0.58, 91, 210, 'Let You Break My Heart Again', 5.4),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de amigos'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _privacy,
            onSelected: (v) => setState(() => _privacy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'private', child: Text('Privado (nadie)')),
              PopupMenuItem(value: 'best_friends', child: Text('Solo mejores amigos')),
              PopupMenuItem(value: 'friends', child: Text('Todos los amigos')),
            ],
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _privacy == 'private'
                  ? 'Tu ubicación está oculta para todos.'
                  : _privacy == 'best_friends'
                      ? 'Solo mejores amigos ven tu ubicación real.'
                      : 'Todos tus amigos pueden verte en el mapa.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.55), fontSize: 13),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return GestureDetector(
                  onTapUp: (d) {
                    // tap friend markers
                    for (final f in _friends) {
                      final x = f.nx * c.maxWidth;
                      final y = f.ny * c.maxHeight;
                      if ((d.localPosition.dx - x).abs() < 36 &&
                          (d.localPosition.dy - y).abs() < 36) {
                        _showFriend(f);
                        break;
                      }
                    }
                  },
                  child: CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _MapPainter(cs, _friends),
                    child: Stack(
                      children: [
                        for (final f in _friends)
                          Positioned(
                            left: f.nx * c.maxWidth - 28,
                            top: f.ny * c.maxHeight - 28,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: cs.primary.withOpacity(0.25),
                                  child: Text(f.name[0],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: cs.primary)),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.surface.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${f.battery}%',
                                      style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFriend(_Friend f) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _row(Icons.battery_std, 'Batería ${f.battery}%'),
            _row(Icons.music_note, '${f.songsListened} canciones escuchadas'),
            _row(Icons.timer_outlined, '${f.hours.toStringAsFixed(1)} h de escucha'),
            _row(Icons.headphones, 'Ahora: ${f.nowPlaying}'),
            const SizedBox(height: 8),
            Text('Reaccionar a su sesión',
                style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final e in ['🔥', '💜', '🎧', '✨'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(e, style: const TextStyle(fontSize: 18)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(i, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
        ]),
      );
}

class _Friend {
  final String name;
  final double nx, ny;
  final int battery, songsListened;
  final String nowPlaying;
  final double hours;
  _Friend(this.name, this.nx, this.ny, this.battery, this.songsListened,
      this.nowPlaying, this.hours);
}

class _MapPainter extends CustomPainter {
  final ColorScheme cs;
  final List<_Friend> friends;
  _MapPainter(this.cs, this.friends);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = cs.surface;
    canvas.drawRect(Offset.zero & size, bg);
    // perspective grid
    final grid = Paint()
      ..color = cs.primary.withOpacity(0.12)
      ..strokeWidth = 1;
    final horizon = size.height * 0.22;
    for (var i = 0; i < 12; i++) {
      final t = i / 11;
      final y = horizon + (size.height - horizon) * pow(t, 1.4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = -8; i <= 8; i++) {
      final x0 = size.width / 2 + i * 40;
      canvas.drawLine(
          Offset(size.width / 2, horizon), Offset(x0 * 1.8 - size.width * 0.4, size.height), grid);
    }
    // soft glow nodes
    for (final f in friends) {
      final p = Offset(f.nx * size.width, f.ny * size.height);
      canvas.drawCircle(
          p,
          40,
          Paint()
            ..color = cs.primary.withOpacity(0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
