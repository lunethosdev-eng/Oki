import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pokke/screens/profile_customize_screen.dart';
import 'package:pokke/screens/friends_map_screen.dart';
import 'package:pokke/screens/chat_list_screen.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _localAvatar;
  String? _localBanner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final remote = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _profile = remote;
        _localAvatar = p.getString('profile_avatar_path');
        _localBanner = p.getString('profile_banner_path');
      });
    }
  }

  ImageProvider? get _avatar {
    final url = _profile?['avatar_url']?.toString();
    if (url != null && url.startsWith('http')) return NetworkImage(url);
    if (_localAvatar != null && File(_localAvatar!).existsSync()) {
      return FileImage(File(_localAvatar!));
    }
    return null;
  }

  Color get _themeColor {
    switch (_profile?['theme']?.toString()) {
      case 'neon':
        return const Color(0xFF00FFC6);
      case 'minimal':
        return Colors.white70;
      case 'sunset':
        return const Color(0xFFFF6B4A);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  BoxDecoration? get _frameDeco {
    switch (_profile?['frame']?.toString()) {
      case 'gold':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFD700), width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x66FFD700), blurRadius: 12)
          ],
        );
      case 'glass':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 16)
          ],
        );
      case 'owner':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _themeColor, width: 3),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _profile?['display_name']?.toString() ??
        _profile?['username']?.toString() ??
        (SupabaseService.isGuest ? 'Invitado' : 'Usuario');
    final isOwner = SupabaseService.isOwner;
    final bio = _profile?['bio']?.toString() ?? '';
    final banner = _profile?['banner_url']?.toString();
    final uid = SupabaseService.currentUser?.id ?? '—';
    final theme = _profile?['theme']?.toString() ?? 'default';
    final frame = _profile?['frame']?.toString() ?? 'none';
    final av = _avatar;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.share('Mi perfil en Pokke: $name'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // Banner (GIF animates via Image.network)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner != null && banner.startsWith('http'))
                    Image.network(banner, fit: BoxFit.cover)
                  else if (_localBanner != null &&
                      File(_localBanner!).existsSync())
                    Image.file(File(_localBanner!), fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _themeColor.withOpacity(0.6),
                            cs.surface,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              decoration: _frameDeco,
              padding: _frameDeco != null ? const EdgeInsets.all(3) : null,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: av,
                child: av == null
                    ? Icon(Icons.person,
                        size: 48, color: cs.onSurface.withOpacity(0.4))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _themeColor)),
          if (isOwner)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('OWNER',
                    style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(bio,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withOpacity(0.55))),
          ],
          const SizedBox(height: 8),
          // Account id
          Center(
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID copiado')),
                );
              },
              child: Text(
                'ID: ${uid.length > 12 ? '${uid.substring(0, 8)}…' : uid}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.4),
                    fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Tema: $theme · Marco: $frame',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Personalizar perfil'),
            subtitle: const Text('Stickers, banner, theme, marco'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileCustomizeScreen()),
              );
              _load();
            },
          ),
          if (SettingsService.instance.flag('friends_map'))
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Mapa de amigos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsMapScreen()),
              ),
            ),
          if (SettingsService.instance.flag('private_chat'))
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Chat privado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            subtitle: const Text('Este dispositivo'),
            onTap: () async {
              await SupabaseService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
