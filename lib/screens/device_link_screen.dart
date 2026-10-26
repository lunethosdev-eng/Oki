import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/services/device_link_service.dart';
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
      Future.delayed(const Duration(milliseconds: 800), () {
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
          : 'Código inválido, expirado o ya usado. ¿Sesión iniciada aquí?';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final payload = DeviceLinkService.instance.pendingPayload ?? _shown ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_hostMode ? 'Vincular este dispositivo' : 'Vincular otro dispositivo'),
        actions: [
          if (!_hostMode)
            TextButton(
              onPressed: _startHost,
              child: const Text('Mostrar código'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            _hostMode
                ? 'En el teléfono donde ya iniciaste sesión: Settings → Vincular dispositivo e introduce el código, o escanea el QR.'
                : 'En el otro dispositivo (TV / tablet) abre Vincular y genera un código. Escríbelo aquí.',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 28),
          if (_hostMode) ...[
            if (_busy && _shown == null)
              const Center(child: CircularProgressIndicator())
            else if (_shown != null) ...[
              Center(
                child: Text(
                  _shown!,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Válido 5 minutos · se actualiza solo al vincular',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.45))),
              ),
              const SizedBox(height: 24),
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
                  'Debes iniciar sesión aquí para enviar la cuenta al otro dispositivo.',
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
                labelText: 'Código del otro dispositivo',
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
