import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionsService {
  static Future<void> requestCore() async {
    try {
      await [
        Permission.notification,
        Permission.microphone,
        Permission.locationWhenInUse,
        Permission.storage,
        Permission.photos,
        Permission.audio,
      ].request();
    } catch (e) {
      debugPrint('permissions: $e');
    }
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }
}
