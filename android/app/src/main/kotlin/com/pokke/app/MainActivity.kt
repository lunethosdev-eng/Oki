package com.pokke.app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "pokke/audio_devices"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listDevices" -> result.success(listDevices())
                    "phoneBattery" -> result.success(phoneBattery())
                    else -> result.notImplemented()
                }
            }
    }

    private fun phoneBattery(): Int {
        return try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (_: Exception) {
            -1
        }
    }

    private fun listDevices(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        out.add(
            mapOf(
                "id" to "phone",
                "name" to "Este teléfono",
                "type" to "speaker",
                "battery" to phoneBattery().takeIf { it in 0..100 },
                "active" to true
            )
        )
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                for (d in devices) {
                    val type = when (d.type) {
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_USB_DEVICE -> "wired"
                        // AUX / line-out / dock often report as:
                        AudioDeviceInfo.TYPE_AUX_LINE,
                        AudioDeviceInfo.TYPE_HDMI,
                        AudioDeviceInfo.TYPE_HDMI_ARC,
                        AudioDeviceInfo.TYPE_DOCK -> "aux"
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> continue
                        else -> continue
                    }
                    val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        d.productName?.toString()?.ifBlank { null }
                    } else null
                    val label = name ?: when (type) {
                        "bluetooth" -> "Bluetooth"
                        "wired" -> "Auriculares"
                        "aux" -> "AUX / Line-out"
                        else -> "Salida"
                    }
                    out.add(
                        mapOf(
                            "id" to "dev_${d.id}",
                            "name" to label,
                            "type" to type,
                            "battery" to null,
                            "active" to false
                        )
                    )
                }
            }
        } catch (_: Exception) {
        }
        return out
    }
}
