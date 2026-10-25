import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pokke/screens/profile_customize_screen.dart';
import 'package:pokke/screens/friends_map_screen.dart';
import 'package:pokke/screens/private_chat_screen.dart';
import 'package:pokke/services/settings_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    SupabaseService.getProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _profile?['display_name']?.toString() ??
        _profile?['username']?.toString() ??
        (SupabaseService.isGuest ? 'Invitado' : 'Usuario');
    final isOwner = SupabaseService.isOwner;

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
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.person, size: 48, color: cs.onSurface.withOpacity(0.4)),
                ),
                if (isOwner)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('OWNER',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Themes · banners GIF · stickers · fuentes\n(customización completa en siguientes iteraciones)',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withOpacity(0.45), height: 1.4),
          ),
          const SizedBox(height: 28),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Personalizar perfil'),
            subtitle: const Text('Stickers, banner, theme'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileCustomizeScreen()),
              );
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
                MaterialPageRoute(builder: (_) => const PrivateChatScreen()),
              ),
            ),
          if (SupabaseService.isLoggedIn && !SupabaseService.isGuest)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                await SupabaseService.signOut();
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
