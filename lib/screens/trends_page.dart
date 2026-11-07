import 'package:flutter/material.dart';

/// Egyelőre minta-adatok. A következő lépésben valódi trendek jönnek
/// (forma, gólok, mindkét csapat szerez gólt) a tabella adataiból.
class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trends = [
      {'title': 'Manchester City szögletei 5.5 felett', 'strength': 9, 'matches': '11/20', 'desc': 'Idegenbeli bajnoki meccseken'},
      {'title': 'Liverpool saját szöglet 6.5+', 'strength': 8, 'matches': '8/12', 'desc': 'Hazai meccseken'},
      {'title': 'Arsenal + Chelsea együtt 9.5+ szöglet', 'strength': 7, 'matches': '7/10', 'desc': 'Egymás elleni meccseken'},
      {'title': 'Tottenham engedett szöglet 5.5+', 'strength': 6, 'matches': '9/15', 'desc': 'Idegenben'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trendek'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trends.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Minta-adatok. A valódi trendek hamarosan érkeznek.',
                style: TextStyle(fontSize: 12),
              ),
            );
          }
          final t = trends[index - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(t['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${t['desc']} • ${t['matches']} meccs'),
              ),
              trailing: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${t['strength']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
