import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/screens/private_chat_screen.dart';

/// Lista de chats con amigos reales (Kokoro).
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (!SupabaseService.isLoggedIn || SupabaseService.isGuest) {
      setState(() {
        _chats = [];
        _loading = false;
      });
      return;
    }
    try {
      final uid = SupabaseService.currentUser!.id;
      final rows = await SupabaseService.kokoro
          .from('chats')
          .select()
          .or('user_a.eq.$uid,user_b.eq.$uid')
          .order('updated_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows as List);
      // enrich with profile of other
      for (final c in list) {
        final other = c['user_a'] == uid ? c['user_b'] : c['user_a'];
        try {
          final prof = await SupabaseService.kokoro
              .from('profiles')
              .select()
              .eq('id', other)
              .maybeSingle();
          c['_other_name'] = prof?['display_name'] ??
              prof?['username'] ??
              other.toString().substring(0, 8);
          c['_other_avatar'] = prof?['avatar_url'];
          c['_other_id'] = other;
        } catch (_) {
          c['_other_name'] = 'Amigo';
          c['_other_id'] = other;
        }
      }
      if (mounted) setState(() => _chats = list);
    } catch (_) {
      if (mounted) setState(() => _chats = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChatById(String friendId) async {
    final uid = SupabaseService.currentUser!.id;
    final fid = friendId.trim();
    if (fid.isEmpty) return;
    try {
      final existing = await SupabaseService.kokoro
          .from('chats')
          .select()
          .or('and(user_a.eq.$uid,user_b.eq.$fid),and(user_a.eq.$fid,user_b.eq.$uid)')
          .maybeSingle();
      String chatId;
      if (existing != null) {
        chatId = existing['id'].toString();
      } else {
        final row = await SupabaseService.kokoro.from('chats').insert({
          'user_a': uid,
          'user_b': fid,
        }).select().single();
        chatId = row['id'].toString();
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(
            chatId: chatId,
            peerId: fid,
            peerName: fid.substring(0, fid.length.clamp(0, 8)),
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ID único del amigo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _startChatById(_addCtrl.text),
                        child: const Text('Chat'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _chats.isEmpty
                      ? Center(
                          child: Text(
                            SupabaseService.isGuest
                                ? 'Inicia sesión para chatear'
                                : 'Sin chats aún.\nAgrega amigos por ID único.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.45)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (_, i) {
                            final c = _chats[i];
                            final name =
                                c['_other_name']?.toString() ?? 'Amigo';
                            final av = c['_other_avatar']?.toString();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: av != null &&
                                        av.startsWith('http')
                                    ? NetworkImage(av)
                                    : null,
                                child: av == null
                                    ? Text(name.isNotEmpty ? name[0] : '?')
                                    : null,
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  c['last_message']?.toString() ?? 'Chat'),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PrivateChatScreen(
                                      chatId: c['id'].toString(),
                                      peerId:
                                          c['_other_id']?.toString() ?? '',
                                      peerName: name,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
