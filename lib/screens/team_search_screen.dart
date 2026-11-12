import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../providers.dart';
import '../services/team_index.dart';
import 'team_screen.dart';

/// Csapatkereső: a lekért meccslistákból épülő helyi csapatindexben keres.
class TeamSearchScreen extends ConsumerStatefulWidget {
  const TeamSearchScreen({super.key});

  @override
  ConsumerState<TeamSearchScreen> createState() => _TeamSearchScreenState();
}

class _TeamSearchScreenState extends ConsumerState<TeamSearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(teamIndexProvider);
    final favs = ref.watch(favoritesProvider);
    final q = foldText(_q.trim());

    List<TeamEntry> results;
    if (q.isEmpty) {
      results = [
        for (final e in favs.entries)
          index[e.key] ?? TeamEntry(e.key, e.value, ''),
      ]..sort((a, b) => a.name.compareTo(b.name));
    } else {
      final hits = <(int, TeamEntry)>[];
      for (final e in index.values) {
        final n = foldText(e.name);
        final pos = n.indexOf(q);
        if (pos < 0) continue;
        hits.add((pos == 0 ? 0 : 1, e));
      }
      hits.sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
      });
      results = [for (final h in hits.take(60)) h.$2];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Csapatkereső'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Csapat neve (pl. Barcelona, Fradi)',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                q.isEmpty
                    ? 'Kedvenc csapataid • ${index.length} csapat a keresőben'
                    : '${results.length} találat • ${index.length} csapat a keresőben',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        index.isEmpty
                            ? 'A csapatlista az első indítás után épül fel a lejátszott '
                                'és a közelgő meccsekből. Nézz vissza pár perc múlva.'
                            : (q.isEmpty
                                ? 'Írj be egy csapatnevet a kereséshez.'
                                : 'Nincs találat. A kereső csak a már látott meccsek csapatait ismeri.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final t = results[i];
                      final fav = favs.containsKey(t.id);
                      return ListTile(
                        title: Text(t.name),
                        subtitle:
                            t.league.isEmpty ? null : Text(leagueHu(t.league)),
                        trailing: IconButton(
                          tooltip: fav
                              ? 'Eltávolítás a kedvencekből'
                              : 'Kedvencnek jelölöm',
                          icon: Icon(
                            fav ? Icons.star : Icons.star_border,
                            color: fav ? Colors.amber : null,
                          ),
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(t.id, t.name),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeamScreen(teamId: t.id, name: t.name),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
