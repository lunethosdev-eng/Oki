import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/services/device_link_service.dart';
import 'package:pokke/services/supabase_service.dart';

/// Phone: enter code from TV. TV: show code to scan/type on phone.
class DeviceLinkScreen extends StatefulWidget {
  /// If true, this device acts as TV host (shows code).
  final bool asTvHost;
  const DeviceLinkScreen({super.key, this.asTvHost = false});

  @override
  State<DeviceLinkScreen> createState() => _DeviceLinkScreenState();
}

class _DeviceLinkScreenState extends State<DeviceLinkScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _shown;
  String? _msg;

  @override
  void initState() {
    super.initState();
    if (widget.asTvHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final isTv = widget.asTvHost ||
              Breakpoints.of(context) == PokkeFormFactor.tv;
          if (isTv) _startHost();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Breakpoints.of(context) == PokkeFormFactor.tv) _startHost();
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() => _busy = true);
    final c = await DeviceLinkService.instance.startTvPairing();
    setState(() {
      _shown = c;
      _busy = false;
    });
  }

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final ok = await DeviceLinkService.instance.claimFromPhone(_code.text);
    setState(() {
      _busy = false;
      _msg = ok
          ? 'Dispositivo vinculado. En la TV debería iniciar sesión sola.'
          : 'Código inválido o expirado. ¿Iniciaste sesión en el teléfono?';
    });
    if (ok && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTv = widget.asTvHost ||
        Breakpoints.of(context) == PokkeFormFactor.tv;

    return Scaffold(
      appBar: AppBar(title: Text(isTv ? 'Vincular con teléfono' : 'Vincular TV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            isTv
                ? 'En tu teléfono (ya con sesión): Settings → Vincular dispositivo e introduce este código.'
                : 'En la TV abre Vincular dispositivo y escribe aquí el código (o el de la QR).',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 28),
          if (isTv) ...[
            if (_busy && _shown == null)
              const Center(child: CircularProgressIndicator())
            else if (_shown != null) ...[
              Center(
                child: Text(
                  _shown!,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Válido 5 minutos',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                ),
              ),
              const SizedBox(height: 24),
              // Simple QR-like visual (payload text for scanner apps / manual)
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      DeviceLinkService.instance.pendingPayload ?? _shown!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'QR payload (escanea o copia el código de arriba)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.45)),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _startHost,
              child: const Text('Generar nuevo código'),
            ),
          ] else ...[
            if (!SupabaseService.isLoggedIn || SupabaseService.isGuest)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Debes iniciar sesión en el teléfono para vincular la TV.',
                  style: TextStyle(color: cs.error),
                ),
              ),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Código de la TV',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _claim,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Vincular'),
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!, style: TextStyle(color: cs.primary)),
          ],
        ],
      ),
    );
  }
}
