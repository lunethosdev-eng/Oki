import 'package:flutter/foundation.dart';
import 'package:pokke/services/supabase_service.dart';

/// Shared song catalog with live refresh after admin cover edits.
class CatalogService extends ChangeNotifier {
  static final CatalogService instance = CatalogService._();
  CatalogService._();

  List<Map<String, dynamic>> songs = [];
  bool loading = false;
  DateTime? lastFetch;

  Future<List<Map<String, dynamic>>> refresh({int limit = 80}) async {
    loading = true;
    notifyListeners();
    try {
      songs = await SupabaseService.getSongs(limit: limit);
      lastFetch = DateTime.now();
    } catch (e) {
      debugPrint('catalog refresh: $e');
    }
    loading = false;
    notifyListeners();
    return songs;
  }

  /// Call after owner panel updates a cover so Home/Search refresh.
  void bump() {
    notifyListeners();
    // fire-and-forget reload
    refresh();
  }
}
