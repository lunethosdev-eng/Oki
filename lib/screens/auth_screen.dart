import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/adaptive/adaptive_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _user = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
          children: [
            Image.asset('assets/logo/pokke_logo.png',
                width: 72, height: 72,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13)),
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
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿Nuevo? Crear cuenta'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _guest,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Continuar como invitado'),
            ),
            const SizedBox(height: 8),
            Text(
              'Guest: sin playlists guardadas si borras la app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
