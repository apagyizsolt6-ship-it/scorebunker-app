import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/league_info.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Bajnokság-szűrő: kiemelés (a Meccsek fül tetejére) és elrejtés.
class LeaguesScreen extends ConsumerStatefulWidget {
  const LeaguesScreen({super.key});

  @override
  ConsumerState<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends ConsumerState<LeaguesScreen> {
  String _q = '';
  bool _onlyWithMatches = true;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(leaguePrefsProvider);
    final data = ref.watch(allLeaguesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bajnokságok'),
        centerTitle: true,
        actions: [
          if (prefs.hidden.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(leaguePrefsProvider.notifier).clearHidden(),
              child: const Text('Rejtettek vissza'),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(allLeaguesProvider),
        ),
        data: (all) {
          final q = _q.trim().toLowerCase();
          final shown = all.where((l) {
            final marked =
                prefs.pinned.contains(l.id) || prefs.hidden.contains(l.id);
            if (_onlyWithMatches && l.fixtures == 0 && !marked) return false;
            if (q.isEmpty) return true;
            final hay =
                '${l.name} ${leagueHu(l.name)} ${l.country} ${countryHu(l.country)}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList()
            ..sort((a, b) {
              final c = countryHu(a.country).compareTo(countryHu(b.country));
              if (c != 0) return c;
              return leagueHu(a.name).compareTo(leagueHu(b.name));
            });

          final items = <Object>[];
          String? last;
          for (final l in shown) {
            if (l.country != last) {
              items.add(l.country);
              last = l.country;
            }
            items.add(l);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Keresés: bajnokság vagy ország',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kiemelt: ${prefs.pinned.length} • Rejtett: ${prefs.hidden.length}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Csak meccsel'),
                      selected: _onlyWithMatches,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) => setState(() => _onlyWithMatches = v),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'A kiemelt bajnokságok meccsei a Meccsek fül tetején jelennek meg, '
                  'a rejtettek nem látszanak a listában.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    if (it is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                        child: Text(
                          countryHu(it).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final l = it as LeagueInfo;
                    final pinned = prefs.pinned.contains(l.id);
                    final hidden = prefs.hidden.contains(l.id);
                    return ListTile(
                      dense: true,
                      title: Text(
                        leagueHu(l.name),
                        style: TextStyle(
                          decoration:
                              hidden ? TextDecoration.lineThrough : null,
                          fontWeight: pinned ? FontWeight.w800 : null,
                        ),
                      ),
                      subtitle: l.fixtures > 0 ? Text('${l.fixtures} meccs az adatbázisban') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: pinned ? 'Kiemelés törlése' : 'Kiemelés',
                            icon: Icon(
                              pinned ? Icons.push_pin : Icons.push_pin_outlined,
                              color: pinned ? Colors.amber : null,
                            ),
                            onPressed: () => ref
                                .read(leaguePrefsProvider.notifier)
                                .togglePin(l.id),
                          ),
                          IconButton(
                            tooltip: hidden ? 'Megjelenítés' : 'Elrejtés',
                            icon: Icon(
                              hidden
                                  ? Icons.visibility_off
                                  : Icons.visibility_outlined,
                              color: hidden ? Colors.red : null,
                            ),
                            onPressed: () => ref
                                .read(leaguePrefsProvider.notifier)
                                .toggleHide(l.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
