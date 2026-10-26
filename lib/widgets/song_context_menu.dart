import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/offline_service.dart';
import 'package:pokke/widgets/liquid_glass.dart';

Future<void> showSongContextMenu(
  BuildContext context, {
  required Map<String, dynamic> song,
  VoidCallback? onAddToPlaylist,
}) {
  final isTv = Breakpoints.of(context) == PokkeFormFactor.tv;
  final title = song['title']?.toString() ?? 'Canción';
  final artist = song['artist']?.toString() ?? '';
  final useGlass = SettingsService.instance.liquidGlassEnabled;
  final cs = Theme.of(context).colorScheme;

  Widget tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: cs.onSurface.withOpacity(0.9)),
      title: Text(label,
          style: TextStyle(
              color: cs.onSurface, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  final items = <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: cs.onSurface)),
                Text(artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    ),
    Divider(height: 1, color: cs.onSurface.withOpacity(0.08)),
    if (!isTv)
      tile(
        icon: Icons.cast_outlined,
        label: 'Transmitir',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Transmitir: elige un dispositivo en el chip del player')),
          );
        },
      ),
    tile(
      icon: Icons.share_outlined,
      label: 'Compartir',
      onTap: () => Share.share('$title — $artist · Pokke'),
    ),
    tile(
      icon: Icons.download_outlined,
      label: 'Descargar (offline)',
      onTap: () {
        OfflineService.instance.downloadSong(song);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga iniciada')),
        );
      },
    ),
    tile(
      icon: Icons.playlist_add,
      label: 'Agregar a playlist',
      onTap: () {
        if (onAddToPlaylist != null) {
          onAddToPlaylist();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Abre Library → playlist')),
          );
        }
      },
    ),
    const SizedBox(height: 8),
  ];

  final panel = ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: useGlass
        ? BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: items),
            ),
          )
        : LiquidGlass(
            borderRadius: BorderRadius.circular(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: items),
          ),
  );

  if (isTv) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
          child: panel,
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: panel,
      ),
    ),
  );
}
