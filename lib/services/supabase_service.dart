import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Kokoro — auth, profiles, playlists, social
  static const String kokoroUrl = 'https://ajbmpgnzkgtcmulocftd.supabase.co';
  static const String kokoroAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqYm1wZ256a2d0Y211bG9jZnRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzNDU2MjksImV4cCI6MjEwNTkyMTYyOX0.twsBnT9WBBILyXFuoQh7viI578yoNbeQztKHsr8DB8k';

  // Ukiyo — music catalog (songs, artists, audio)
  static const String ukiyoUrl = 'https://esjoifsjljvymttinyhj.supabase.co';
  static const String ukiyoAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzam9pZnNqbGp2eW10dGlueWhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwMzYyMTAsImV4cCI6MjEwNjYxMjIxMH0.GKA3KyoMElVwLUQlL2ad82IPjRmwKmMJEGPTUNwbuVQ';

  static const String reservedEmail = 'lunethos.dev@gmail.com';
  static const String ownerPin = '4049959';

  static late final SupabaseClient kokoro;
  static late final SupabaseClient ukiyo;

  static Future<void> init() async {
    await Supabase.initialize(url: kokoroUrl, anonKey: kokoroAnonKey);
    kokoro = Supabase.instance.client;
    ukiyo = SupabaseClient(ukiyoUrl, ukiyoAnonKey);
  }

  static User? get currentUser => kokoro.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static bool get isOwner =>
      currentUser?.email?.toLowerCase() == reservedEmail;
  static bool get isGuest =>
      currentUser == null ||
      currentUser!.isAnonymous == true ||
      (currentUser!.email == null || currentUser!.email!.isEmpty);

  static Future<AuthResponse> signIn(
      {required String email, required String password}) {
    return kokoro.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await kokoro.auth.signUp(email: email, password: password);
    if (res.user != null && username != null && username.isNotEmpty) {
      try {
        await kokoro.from('profiles').upsert({
          'id': res.user!.id,
          'username': username,
          'display_name': username,
        });
      } catch (_) {}
    }
    return res;
  }

  static Future<void> signOut() => kokoro.auth.signOut();

  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    try {
      return await kokoro
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    data['id'] = currentUser!.id;
    await kokoro.from('profiles').upsert(data);
  }

  /// Songs from **Ukiyo** catalog
  static Future<List<Map<String, dynamic>>> searchSongs(String query,
      {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final res = await ukiyo
          .from('songs')
          .select()
          .or('title.ilike.%$q%,artist.ilike.%$q%')
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getSongs({int limit = 40}) async {
    try {
      final res = await ukiyo
          .from('songs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getSongById(String id) async {
    try {
      return await ukiyo.from('songs').select().eq('id', id).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getArtists({int limit = 30}) async {
    try {
      final res =
          await ukiyo.from('artists').select().order('name').limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }
}
