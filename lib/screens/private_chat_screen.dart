import 'package:flutter/material.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key});
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _ctrl = TextEditingController();
  final _messages = <_Msg>[
    _Msg('Aya', '¿Qué estás escuchando?', false, DateTime.now().subtract(const Duration(minutes: 12))),
    _Msg('Tú', 'Laufey — From The Start 🔥', true, DateTime.now().subtract(const Duration(minutes: 10))),
    _Msg('Aya', 'Esa es top. Racha 3 días ⚡', false, DateTime.now().subtract(const Duration(minutes: 8))),
  ];
  String _bg = 'default';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = switch (_bg) {
      'blue' => const Color(0xFF0A1628),
      'purple' => const Color(0xFF1A0F24),
      'green' => const Color(0xFF0C1A14),
      _ => cs.surface,
    };
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('🔋 78% · escuchando ahora',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _bg = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'default', child: Text('Fondo default')),
              PopupMenuItem(value: 'blue', child: Text('Azul noche')),
              PopupMenuItem(value: 'purple', child: Text('Púrpura')),
              PopupMenuItem(value: 'green', child: Text('Verde')),
            ],
            icon: const Icon(Icons.wallpaper_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.primary.withOpacity(0.12),
            child: const Text('🔥 Racha 3 días · compartiendo música en vivo',
                style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? cs.primary.withOpacity(0.85)
                          : cs.surfaceContainerHighest.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text,
                            style: TextStyle(
                                color: m.mine
                                    ? cs.onPrimary
                                    : cs.onSurface)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in ['👍', '❤️', '🔥'])
                              InkWell(
                                onTap: () {},
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file),
                    tooltip: 'Imagen / audio / video',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Mensaje…',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      final t = _ctrl.text.trim();
                      if (t.isEmpty) return;
                      setState(() {
                        _messages.add(_Msg('Tú', t, true, DateTime.now()));
                        _ctrl.clear();
                      });
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String from, text;
  final bool mine;
  final DateTime at;
  _Msg(this.from, this.text, this.mine, this.at);
}
