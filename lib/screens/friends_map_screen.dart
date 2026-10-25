import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real-world map. Friends come from Kokoro `friendships` + `presence`.
/// Privacy: private | friends | best_friends
class FriendsMapScreen extends StatefulWidget {
  const FriendsMapScreen({super.key});
  @override
  State<FriendsMapScreen> createState() => _FriendsMapScreenState();
}

class _FriendsMapScreenState extends State<FriendsMapScreen> {
  final _map = MapController();
  String _privacy = 'best_friends';
  LatLng? _me;
  int? _battery;
  List<_FriendPin> _friends = [];
  StreamSubscription<Position>? _posSub;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final p = await SharedPreferences.getInstance();
    _privacy = p.getString('map_privacy') ?? 'best_friends';
    await _ensurePermission();
    await _loadFriends();
    await _startLocation();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      setState(() => _error = 'Permiso de ubicación denegado');
    }
  }

  Future<void> _startLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _me = LatLng(pos.latitude, pos.longitude);
      _publishPresence();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((p) {
        setState(() => _me = LatLng(p.latitude, p.longitude));
        _publishPresence();
      });
    } catch (e) {
      setState(() => _error = 'No se pudo obtener GPS: $e');
    }
  }

  Future<void> _publishPresence() async {
    if (_me == null || !SupabaseService.isLoggedIn || SupabaseService.isGuest) {
      return;
    }
    if (_privacy == 'private') return;
    try {
      await SupabaseService.kokoro.from('presence').upsert({
        'user_id': SupabaseService.currentUser!.id,
        'lat': _me!.latitude,
        'lng': _me!.longitude,
        'privacy': _privacy,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _loadFriends() async {
    if (!SupabaseService.isLoggedIn || SupabaseService.isGuest) {
      setState(() => _friends = []);
      return;
    }
    try {
      // friendships where I am user_id
      final rows = await SupabaseService.kokoro
          .from('friendships')
          .select('friend_id, is_best')
          .eq('user_id', SupabaseService.currentUser!.id);
      final list = List<Map<String, dynamic>>.from(rows as List);
      final pins = <_FriendPin>[];
      for (final f in list) {
        if (_privacy == 'best_friends' && f['is_best'] != true) continue;
        final fid = f['friend_id']?.toString();
        if (fid == null) continue;
        try {
          final pres = await SupabaseService.kokoro
              .from('presence')
              .select()
              .eq('user_id', fid)
              .maybeSingle();
          final prof = await SupabaseService.kokoro
              .from('profiles')
              .select()
              .eq('id', fid)
              .maybeSingle();
          if (pres == null) continue;
          final lat = (pres['lat'] as num?)?.toDouble();
          final lng = (pres['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          // respect their privacy
          final their = pres['privacy']?.toString() ?? 'friends';
          if (their == 'private') continue;
          if (their == 'best_friends' && f['is_best'] != true) continue;
          pins.add(_FriendPin(
            id: fid,
            name: prof?['display_name']?.toString() ??
                prof?['username']?.toString() ??
                'Amigo',
            avatar: prof?['avatar_url']?.toString(),
            lat: lat,
            lng: lng,
            battery: (pres['battery'] as num?)?.toInt(),
            song: pres['now_playing']?.toString(),
            listenMin: (pres['listen_min'] as num?)?.toDouble() ?? 0,
          ));
        } catch (_) {}
      }
      if (mounted) setState(() => _friends = pins);
    } catch (_) {
      if (mounted) setState(() => _friends = []);
    }
  }

  Future<void> _setPrivacy(String v) async {
    setState(() => _privacy = v);
    final p = await SharedPreferences.getInstance();
    await p.setString('map_privacy', v);
    await _publishPresence();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final center = _me ?? const LatLng(13.6929, -89.2182); // SV default

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de amigos'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _privacy,
            onSelected: _setPrivacy,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'private', child: Text('Privado (nadie)')),
              PopupMenuItem(
                  value: 'best_friends',
                  child: Text('Solo mejores amigos')),
              PopupMenuItem(
                  value: 'friends', child: Text('Todos mis amigos')),
            ],
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadFriends();
              await _startLocation();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pokke.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_me != null)
                          Marker(
                            point: _me!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.4),
                                    blurRadius: 12,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        for (final f in _friends)
                          Marker(
                            point: LatLng(f.lat, f.lng),
                            width: 52,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => _showFriend(f),
                              child: CircleAvatar(
                                backgroundImage: f.avatar != null &&
                                        f.avatar!.startsWith('http')
                                    ? NetworkImage(f.avatar!)
                                    : null,
                                child: f.avatar == null
                                    ? Text(f.name.characters.first)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_error != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: Material(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!,
                            style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(14),
                    color: cs.surface.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _privacy == 'private'
                            ? 'Tu ubicación es privada. Nadie la ve.'
                            : 'Compartes ubicación solo con ${_privacy == 'best_friends' ? 'mejores amigos' : 'amigos'} (ID único).',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.75)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_me != null) {
            _map.move(_me!, 15);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showFriend(_FriendPin f) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: f.avatar != null
                      ? NetworkImage(f.avatar!)
                      : null,
                  child: f.avatar == null ? Text(f.name[0]) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (f.battery != null)
                        Text('🔋 ${f.battery}%',
                            style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (f.song != null) Text('Escuchando: ${f.song}'),
            Text('Tiempo escuchando: ${f.listenMin.toStringAsFixed(1)} min'),
            Text('ID: ${f.id}',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
          ],
        ),
      ),
    );
  }
}

class _FriendPin {
  final String id;
  final String name;
  final String? avatar;
  final double lat;
  final double lng;
  final int? battery;
  final String? song;
  final double listenMin;
  _FriendPin({
    required this.id,
    required this.name,
    this.avatar,
    required this.lat,
    required this.lng,
    this.battery,
    this.song,
    this.listenMin = 0,
  });
}
