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

  Widget tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  final body = Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      if (!isTv)
        tile(
          icon: Icons.cast_outlined,
          label: 'Transmitir',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Transmitir: elige un dispositivo en el chip del player')),
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
        onTap: () async {
          final ok = await OfflineService.instance.downloadSong(song);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(ok
                      ? 'Descargada en Music/Pokke'
                      : 'No se pudo descargar')),
            );
          }
        },
      ),
      tile(
        icon: Icons.playlist_add,
        label: 'Agregar a playlist',
        onTap: () => onAddToPlaylist?.call(),
      ),
      const SizedBox(height: 12),
    ],
  );

  if (isTv) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: const Color(0xFF1C1C1F),
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
            child: body,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final sheet = Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(top: false, child: body),
      );
      if (useGlass) {
        return LiquidGlass(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: sheet,
        );
      }
      return sheet;
    },
  );
}
