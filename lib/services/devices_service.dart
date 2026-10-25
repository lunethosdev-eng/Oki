import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ConnectedDevice {
  final String id;
  final String name;
  final String type; // bluetooth | wired | speaker | cast
  final int? battery; // 0-100
  final bool active;
  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    this.battery,
    this.active = false,
  });
}

/// Bluetooth / wired / cast devices — phone + TV.
class DevicesService extends ChangeNotifier {
  static final DevicesService instance = DevicesService._();
  DevicesService._();

  static const _ch = MethodChannel('pokke/audio_devices');
  List<ConnectedDevice> devices = [];
  ConnectedDevice? active;

  Future<void> refresh() async {
    try {
      final raw = await _ch.invokeMethod('listDevices');
      if (raw is List) {
        devices = raw.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return ConnectedDevice(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? 'Dispositivo',
            type: m['type']?.toString() ?? 'bluetooth',
            battery: m['battery'] is int ? m['battery'] as int : null,
            active: m['active'] == true,
          );
        }).toList();
        active = devices.where((d) => d.active).cast<ConnectedDevice?>().firstOrNull ??
            (devices.isNotEmpty ? devices.first : null);
        notifyListeners();
        return;
      }
    } catch (_) {}
    // Fallback soft list so UI always has something to show structure
    devices = [
      ConnectedDevice(
        id: 'phone',
        name: 'Este teléfono',
        type: 'speaker',
        battery: null,
        active: true,
      ),
    ];
    active = devices.first;
    notifyListeners();
  }

  IconData iconFor(String type) {
    switch (type) {
      case 'bluetooth':
        return Icons.bluetooth_connected_rounded;
      case 'wired':
        return Icons.headphones_rounded;
      case 'cast':
        return Icons.cast_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }
}
