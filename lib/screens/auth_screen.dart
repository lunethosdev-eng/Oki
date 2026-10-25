import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/adaptive/adaptive_shell.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:pokke/screens/device_link_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _user = TextEditingController();
  final _pin = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  bool get _isOwnerEmail =>
      _email.text.trim().toLowerCase() == SupabaseService.reservedEmail;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_register && _isOwnerEmail) {
        if (_pin.text.trim() != SupabaseService.ownerPin) {
          throw Exception('PIN de owner incorrecto');
        }
      }
      if (_register) {
        await SupabaseService.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          username: _user.text.trim(),
        );
      } else {
        await SupabaseService.signIn(
          email: _email.text.trim(),
          password: _pass.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdaptiveShell()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _guest() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdaptiveShell(guest: true)));
  }

  Future<void> _support() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'lunethos.dev@gmail.com',
      queryParameters: {
        'subject': 'Pokke soporte',
        'body': 'Hola, necesito ayuda con Pokke:\n\n',
      },
    );
    await launchUrl(uri);
  }

  void _linkDevice() {
    final isTv = Breakpoints.of(context) == PokkeFormFactor.tv;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceLinkScreen(asTvHost: isTv),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _user.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'support') _support();
              if (v == 'link') _linkDevice();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'support',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Soporte / Ayuda'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'link',
                child: ListTile(
                  leading: Icon(Icons.cast_connected_outlined),
                  title: Text('Vincular dispositivo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            Image.asset('assets/logo/pokke_logo.png',
                width: 72,
                height: 72,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.album, size: 72, color: cs.onSurface)),
            const SizedBox(height: 20),
            Text(_register ? 'Crear cuenta' : 'Iniciar sesión',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 6),
            Text(
              'Minimal. Professional. Yours.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
            ),
            const SizedBox(height: 32),
            if (_register) ...[
              TextField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (!_register && _isOwnerEmail) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Owner PIN',
                  border: OutlineInputBorder(),
                  helperText: 'Solo cuenta owner',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_register ? 'Registrarse' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              child: Text(_register
                  ? '¿Ya tienes cuenta? Entrar'
                  : 'Crear cuenta'),
            ),
            TextButton(
              onPressed: _guest,
              child: const Text('Continuar como invitado'),
            ),
          ],
        ),
      ),
    );
  }
}
