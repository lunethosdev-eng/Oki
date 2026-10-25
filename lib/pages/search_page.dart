import 'package:flutter/material.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<String> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!SettingsService.instance.saveSearchHistory) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('search_history_v1');
    if (raw != null) {
      setState(() =>
          _history = List<String>.from(jsonDecode(raw) as List));
    }
  }

  Future<void> _saveHistory(String q) async {
    if (!SettingsService.instance.saveSearchHistory) return;
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 30) _history = _history.sublist(0, 30);
    final p = await SharedPreferences.getInstance();
    await p.setString('search_history_v1', jsonEncode(_history));
    setState(() {});
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _loading = true);
    await _saveHistory(q.trim());
    final res = await MusicApiService.search(q.trim());
    if (mounted) {
      setState(() {
        _results = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Buscar canciones, artistas…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                    children: [
                      if (SettingsService.instance.saveSearchHistory &&
                          _history.isNotEmpty) ...[
                        Text('Historial',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        const SizedBox(height: 8),
                        for (final h in _history)
                          ListTile(
                            leading: Icon(Icons.history,
                                color: cs.onSurface.withOpacity(0.4)),
                            title: Text(h,
                                style: TextStyle(color: cs.onSurface)),
                            onTap: () {
                              _ctrl.text = h;
                              _search(h);
                            },
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Busca en el catálogo Pokke / Ukiyo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.45)),
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final s = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(s['title']?.toString() ?? ''),
                        subtitle: Text(s['artist']?.toString() ?? ''),
                        onTap: () => PlayerController.instance
                            .playSong(s, asQueue: _results),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
