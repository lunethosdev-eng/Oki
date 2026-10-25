import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/listen_together_service.dart';

class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});
  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  final _join = TextEditingController();

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ListenTogetherService.instance;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Listen together')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Beta · Comparte un código. Misma canción y posición (sync en tiempo real se amplía con Supabase Realtime).',
                style: TextStyle(color: cs.onSurface.withOpacity(0.55), height: 1.4),
              ),
              const SizedBox(height: 24),
              if (!svc.active) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final code = await svc.host();
                    if (code != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sala $code')),
                      );
                    }
                  },
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Crear sala (host)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _join,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                    hintText: 'ABC123',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => svc.join(_join.text),
                  child: const Text('Unirse'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text('Código',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(svc.roomCode ?? '—',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4)),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: svc.roomCode ?? ''));
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                      Text(svc.isHost ? 'Eres el host' : 'Invitado',
                          style: TextStyle(color: cs.primary)),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: svc.dualSession,
                        onChanged: svc.setDualSession,
                        title: const Text('Sesión dual (beta)'),
                        subtitle: const Text('Dos pares / misma sesión'),
                      ),
                      TextButton(onPressed: svc.leave, child: const Text('Salir')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
