import 'package:flutter/material.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        children: [
          Text('Browse',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 16),
          Text('Categorías y descubrimiento — se conecta al catálogo Pokke.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}
