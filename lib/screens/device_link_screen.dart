import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/services/device_link_service.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/adaptive/adaptive_shell.dart';

class DeviceLinkScreen extends StatefulWidget {
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
  bool _hostMode = false;

  @override
  void initState() {
    super.initState();
    DeviceLinkService.instance.addListener(_onLink);
    DevicesService.instance.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isTv = widget.asTvHost ||
          Breakpoints.of(context) == PokkeFormFactor.tv;
      if (isTv) {
        setState(() => _hostMode = true);
        _startHost();
      }
    });
  }

  void _onLink() {
    if (DeviceLinkService.instance.linked && mounted) {
      setState(() => _msg = '¡Cuenta vinculada!');
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdaptiveShell()),
          (_) => false,
        );
      });
    }
  }

  @override
  void dispose() {
    DeviceLinkService.instance.removeListener(_onLink);
    _code.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() {
      _busy = true;
      _hostMode = true;
      _msg = null;
    });
    final c = await DeviceLinkService.instance.startHostPairing();
    if (mounted) {
      setState(() {
        _shown = c;
        _busy = false;
      });
    }
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
          ? 'Código enviado. El otro dispositivo debería entrar solo.'
          : 'Código inválido/expirado o sin sesión aquí.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final payload =
        DeviceLinkService.instance.pendingPayload ?? _shown ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_hostMode
            ? 'Mostrar código'
            : 'Vincular otro dispositivo'),
        actions: [
          if (!_hostMode)
            TextButton(onPressed: _startHost, child: const Text('Mostrar código')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            _hostMode
                ? 'En el teléfono con sesión: Settings → Vincular → escribe este código.'
                : 'En TV/tablet: abre Vincular → Mostrar código. Escríbelo aquí (debes tener sesión).',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 20),
          // Connected devices
          AnimatedBuilder(
            animation: DevicesService.instance,
            builder: (_, __) {
              final devs = DevicesService.instance.devices;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dispositivos de audio',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 6),
                  if (devs.isEmpty)
                    Text('Ninguno detectado',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.45)))
                  else
                    ...devs.map((d) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(DevicesService.instance.iconFor(d.type)),
                          title: Text(d.name),
                          subtitle: Text(
                              '${d.type}${d.battery != null ? ' · ${d.battery}%' : ''}'),
                          trailing: d.active
                              ? Icon(Icons.check_circle, color: cs.primary)
                              : null,
                        )),
                  TextButton.icon(
                    onPressed: () => DevicesService.instance.refresh(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 28),
          if (_hostMode) ...[
            if (_busy && _shown == null)
              const Center(child: CircularProgressIndicator())
            else if (_shown != null) ...[
              Center(
                child: Text(_shown!,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: cs.primary,
                    )),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Válido 5 minutos',
                    style:
                        TextStyle(color: cs.onSurface.withOpacity(0.45))),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _startHost,
              child: const Text('Generar nuevo código'),
            ),
          ] else ...[
            if (!SupabaseService.isLoggedIn || SupabaseService.isGuest)
              Text('Inicia sesión en este teléfono para enviar la cuenta.',
                  style: TextStyle(color: cs.error)),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Código del otro dispositivo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
