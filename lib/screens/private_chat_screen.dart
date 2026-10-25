import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String peerId;
  final String peerName;
  const PrivateChatScreen({
    super.key,
    required this.chatId,
    required this.peerId,
    required this.peerName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  StreamSubscription? _sub;
  String _bg = 'default';
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.kokoro
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true)
          .limit(200);
      if (mounted) {
        setState(() => _msgs = List<Map<String, dynamic>>.from(rows as List));
        _jump();
      }
    } catch (_) {}
  }

  void _subscribe() {
    try {
      _sub = SupabaseService.kokoro
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', widget.chatId)
          .listen((rows) {
        if (!mounted) return;
        setState(() => _msgs = List<Map<String, dynamic>>.from(rows));
        _jump();
      });
    } catch (_) {}
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !SupabaseService.isLoggedIn) return;
    _ctrl.clear();
    try {
      await SupabaseService.kokoro.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': SupabaseService.currentUser!.id,
        'body': text,
        'type': 'text',
      });
      await SupabaseService.kokoro.from('chats').update({
        'last_message': text,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.chatId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _react(String msgId, String emoji) async {
    try {
      await SupabaseService.kokoro.from('message_reactions').upsert({
        'message_id': msgId,
        'user_id': SupabaseService.currentUser!.id,
        'emoji': emoji,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = switch (_bg) {
      'blue' => const Color(0xFF0B1C2C),
      'purple' => const Color(0xFF1A0B2E),
      'green' => const Color(0xFF0B2C1A),
      _ => cs.surface,
    };
    final uid = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text('ID ${widget.peerId.length > 8 ? widget.peerId.substring(0, 8) : widget.peerId}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('🔥 $_streak')),
            ),
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
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                final mine = m['sender_id'] == uid;
                final body = m['body']?.toString() ?? '';
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _react(m['id'].toString(), '❤️'),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                      decoration: BoxDecoration(
                        color: mine
                            ? cs.primary
                            : cs.surfaceContainerHighest.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        body,
                        style: TextStyle(
                          color: mine ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
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
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
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
