import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionsService {
  /// Request all runtime permissions Pokke needs.
  /// Call from a user gesture (Settings tile) — more reliable than boot.
  static Future<Map<Permission, PermissionStatus>> requestCore() async {
    final wanted = <Permission>[
      Permission.notification,
      Permission.microphone,
      Permission.locationWhenInUse,
      Permission.audio,
      Permission.photos,
      Permission.videos,
      Permission.storage, // pre-Android 13
    ];
    Map<Permission, PermissionStatus> result = {};
    try {
      result = await wanted.request();
      debugPrint('permissions: $result');
    } catch (e) {
      debugPrint('permissions request: $e');
    }
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      debugPrint('geolocator: $p');
    } catch (e) {
      debugPrint('geolocator: $e');
    }
    return result;
  }
}
