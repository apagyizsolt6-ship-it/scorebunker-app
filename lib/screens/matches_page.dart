import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../models/live_score.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'match_detail_screen.dart';
import 'standings_screen.dart';

// ==================== CSOPORTOSÍTÁS (kedvencek + top bajnokságok + országok) ====================
const String _otherLabel = 'Nemzetközi / egyéb';

/// Zászló emoji az országkódból (pl. "ES", "GB-ENG", "EU").
String _flagFor(String geo) {
  final g = geo.toUpperCase();
  const tags = {'GB-ENG': 'gbeng', 'GB-SCT': 'gbsct', 'GB-WLS': 'gbwls'};
  final t = tags[g];
  if (t != null) {
    return String.fromCharCodes(
        [0x1F3F4, ...t.codeUnits.map((c) => 0xE0000 + c), 0xE007F]);
  }
  final ok = g.length == 2 || (g.length > 2 && g[2] == '-');
  if (!ok) return '🌐';
  final cc = g.substring(0, 2);
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return '🌐';
  return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

class _Group {
  final String key;
  final String title;
  final String geo;
  final bool isTop;
  final bool isFav;
  final Map<String, List<Fixture>> leagues = {};

  _Group(this.key, this.title, this.geo, this.isTop, {this.isFav = false});

  int get count => leagues.values.fold(0, (s, l) => s + l.length);
  int get live =>
      leagues.values.fold(0, (s, l) => s + l.where((m) => m.isLive).length);
}

class _LeagueTitle {
  final String name;
  final int leagueId;
  const _LeagueTitle(this.name, this.leagueId);
}

class _SectionLabel {
  final String text;
  const _SectionLabel(this.text);
}

List<_Group> _groupFixtures(List<Fixture> list, Set<int> favIds) {
  final tops = <String, _Group>{};
  final countries = <String, _Group>{};
  _Group? fav;

  for (final m in list) {
    if (favIds.contains(m.homeId) || favIds.contains(m.awayId)) {
      final fg = fav ??= _Group('fav', 'Kedvenceim', '', true, isFav: true);
      fg.leagues.putIfAbsent(m.leagueName, () => []).add(m);
    }
    final t = topLeagueOf(m);
    if (t != null) {
      final g = tops.putIfAbsent(
          t.key, () => _Group('top:${t.key}', t.nameHu, t.geo, true));
      g.leagues.putIfAbsent(m.leagueName, () => []).add(m);
    } else {
      final zone = m.leagueZone.isEmpty ? _otherLabel : m.leagueZone;
      final g = countries.putIfAbsent(
        zone,
        () => _Group(
          'c:$zone',
          zone == _otherLabel ? _otherLabel : countryHu(zone),
          m.leagueGeo,
          false,
        ),
      );
      g.leagues.putIfAbsent(m.leagueName, () => []).add(m);
    }
  }

  final order = {
    for (var i = 0; i < topLeagues.length; i++) topLeagues[i].key: i,
  };
  final topList = tops.entries.toList()
    ..sort((a, b) => order[a.key]!.compareTo(order[b.key]!));
  final countryList = countries.values.toList()
    ..sort((a, b) {
      if (a.title == _otherLabel) return 1;
      if (b.title == _otherLabel) return -1;
      return a.title.compareTo(b.title);
    });

  final favGroup = fav;
  return [
    if (favGroup != null) favGroup,
    ...topList.map((e) => e.value),
    ...countryList,
  ];
}

List<Fixture> _applySearch(List<Fixture> list, String q) {
  final query = q.trim().toLowerCase();
  if (query.isEmpty) return list;
  return list.where((m) {
    final top = topLeagueOf(m);
    final hay = [
      m.homeTeam,
      m.awayTeam,
      m.leagueName,
      leagueHu(m.leagueName),
      m.leagueZone,
      countryHu(m.leagueZone),
      if (top != null) top.nameHu,
    ].join(' | ').toLowerCase();
    return hay.contains(query);
  }).toList();
}

List<Fixture> _applyFilter(
  List<Fixture> list,
  MatchFilter filter,
  bool favOnly,
  Set<int> favIds,
) {
  return list.where((m) {
    if (favOnly && !(favIds.contains(m.homeId) || favIds.contains(m.awayId))) {
      return false;
    }
    return switch (filter) {
      MatchFilter.all => true,
      MatchFilter.live => m.isLive,
      MatchFilter.upcoming => m.isScheduled,
      MatchFilter.finished => m.isFinished,
    };
  }).toList();
}

// ==================== MECCSEK ====================
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyState = ref.watch(apiKeyProvider);
    final query = ref.watch(searchQueryProvider);
    final collapsed = ref.watch(collapsedCountriesProvider);
    final filter = ref.watch(matchFilterProvider);
    final favOnly = ref.watch(favOnlyProvider);
    final favs = ref.watch(favoritesProvider);
    final favIds = favs.keys.toSet();
    final all = ref.watch(liveFixturesProvider).valueOrNull ?? const <Fixture>[];

    final liveCount = all.where((m) => m.isLive).length;
    final allKeys = _groupFixtures(all, favIds).map((g) => g.key).toSet();
    final allCollapsed = allKeys.isNotEmpty && allKeys.every(collapsed.contains);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scorebunker'),
        centerTitle: true,
        actions: [
          const _LiveDot(),
          IconButton(
            tooltip: allCollapsed ? 'Összes kinyitása' : 'Összes összecsukása',
            icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
            onPressed: () {
              ref.read(collapsedCountriesProvider.notifier).state =
                  allCollapsed ? <String>{} : {...allKeys};
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(fixturesProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: _DateBar(),
        ),
      ),
      body: keyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (k) {
          if (k == null || k.isEmpty) return const NoKeyView();
          final fixtures = ref.watch(liveFixturesProvider);
          return Column(
            children: [
              const _SearchField(),
              _FilterBar(liveCount: liveCount),
              Expanded(
                child: fixtures.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(fixturesProvider),
                  ),
                  data: (list) {
                    final filtered = _applyFilter(
                      _applySearch(list, query),
                      filter,
                      favOnly,
                      favIds,
                    );
                    if (filtered.isEmpty) {
                      String msg = 'Nincs találat.';
                      if (list.isEmpty) {
                        msg = 'Nincs meccs ezen a napon.';
                      } else if (favOnly && favIds.isEmpty) {
                        msg = 'Még nincs kedvenc csapatod.\n'
                            'Egy meccskártyán nyomd hosszan, és jelöld meg a csapatot.';
                      } else if (filter == MatchFilter.live) {
                        msg = 'Jelenleg nincs élő meccs.';
                      }
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(msg, textAlign: TextAlign.center),
                        ),
                      );
                    }
                    final groups = _groupFixtures(filtered, favIds);
                    // Keresés közben mindent mutatunk.
                    final hidden =
                        query.trim().isEmpty ? collapsed : <String>{};

                    final items = <Object>[];
                    var topLabel = false;
                    var countryLabel = false;
                    for (final g in groups) {
                      if (!g.isFav && g.isTop && !topLabel) {
                        items.add(const _SectionLabel('⭐ TOP BAJNOKSÁGOK'));
                        topLabel = true;
                      }
                      if (!g.isTop && topLabel && !countryLabel) {
                        items.add(const _SectionLabel('ORSZÁGOK'));
                        countryLabel = true;
                      }
                      items.add(g);
                      if (hidden.contains(g.key)) continue;
                      if (g.isTop) {
                        final matches = g.leagues.values
                            .expand((l) => l)
                            .toList()
                          ..sort(byKickoff);
                        items.addAll(matches);
                      } else {
                        final names = g.leagues.keys.toList()
                          ..sort((a, b) =>
                              leagueHu(a).compareTo(leagueHu(b)));
                        for (final n in names) {
                          final ms = <Fixture>[...g.leagues[n]!]
                            ..sort(byKickoff);
                          items.add(_LeagueTitle(leagueHu(n), ms.first.leagueId));
                          items.addAll(ms);
                        }
                      }
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(fixturesProvider);
                        await ref.read(fixturesProvider.future);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is _SectionLabel) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, top: 16, bottom: 2),
                              child: Text(
                                item.text,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          if (item is _Group) {
                            return _GroupHeader(
                              group: item,
                              collapsed: hidden.contains(item.key),
                              onTap: () {
                                final s = {
                                  ...ref.read(collapsedCountriesProvider)
                                };
                                if (!s.remove(item.key)) s.add(item.key);
                                ref
                                    .read(collapsedCountriesProvider.notifier)
                                    .state = s;
                              },
                            );
                          }
                          if (item is _LeagueTitle) {
                            return InkWell(
                              onTap: item.leagueId == 0
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StandingsScreen(
                                            leagueId: item.leagueId,
                                            title: item.name,
                                          ),
                                        ),
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, top: 10, bottom: 6),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    if (item.leagueId != 0) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.leaderboard_outlined,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MatchCard(fixture: item as Fixture),
                          );
                        },
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

/// Az élő (WebSocket) kapcsolat állapota: zöld = él, narancs = kapcsolódik,
/// szürke = nincs kapcsolat. Koppintásra újra próbál csatlakozni.
class _LiveDot extends ConsumerWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(liveProvider.select((s) => s.conn));
    final (Color color, String text) = switch (conn) {
      LiveConn.on => (Colors.green, 'Élő frissítés: kapcsolódva'),
      LiveConn.connecting => (Colors.orange, 'Élő frissítés: kapcsolódás…'),
      LiveConn.off => (Colors.grey, 'Élő frissítés: nincs kapcsolat'),
    };
    return Tooltip(
      message: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
          ref.read(liveProvider.notifier).ensureConnected();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Icon(Icons.circle, size: 12, color: color),
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final int liveCount;
  const _FilterBar({required this.liveCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(matchFilterProvider);
    final favOnly = ref.watch(favOnlyProvider);

    Widget chip(String label, MatchFilter v) => ChoiceChip(
          label: Text(label),
          selected: filter == v,
          onSelected: (_) => ref.read(matchFilterProvider.notifier).state = v,
        );

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          chip('Mind', MatchFilter.all),
          const SizedBox(width: 8),
          chip(liveCount > 0 ? 'Élő ($liveCount)' : 'Élő', MatchFilter.live),
          const SizedBox(width: 8),
          chip('Hamarosan', MatchFilter.upcoming),
          const SizedBox(width: 8),
          chip('Vége', MatchFilter.finished),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
            label: const Text('Kedvencek'),
            selected: favOnly,
            onSelected: (v) => ref.read(favOnlyProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _c,
        onChanged: (v) {
          ref.read(searchQueryProvider.notifier).state = v;
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Keresés: csapat, bajnokság, ország',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _c.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final _Group group;
  final bool collapsed;
  final VoidCallback onTap;
  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: group.isFav
            ? Colors.amber.withValues(alpha: 0.22)
            : group.isTop
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(group.isFav ? '⭐' : _flagFor(group.geo),
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (group.live > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ÉLŐ ${group.live}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('${group.count}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(selectedDateProvider);
    void setDate(DateTime x) =>
        ref.read(selectedDateProvider.notifier).state = x;
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final label = DateFormat('yyyy.MM.dd').format(d) + (isToday ? ' (ma)' : '');

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setDate(DateTime(d.year, d.month, d.day - 1)),
          ),
          TextButton(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: d,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (p != null) setDate(p);
            },
            child: Text(label),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setDate(DateTime(d.year, d.month, d.day + 1)),
          ),
        ],
      ),
    );
  }
}

class MatchCard extends ConsumerWidget {
  final Fixture fixture;
  const MatchCard({super.key, required this.fixture});

  Widget _team(int id, String name, bool fav) {
    return Row(
      children: [
        TeamLogo(teamId: id, size: 18),
        if (fav) ...[
          const Icon(Icons.star, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final scheme = Theme.of(context).colorScheme;
    final favs = ref.watch(favoritesProvider);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)),
          );
        },
        onLongPress: () => showTeamFavSheet(context, f),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  f.timeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: f.isLive ? Colors.red : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _team(f.homeId, f.homeTeam, favs.containsKey(f.homeId)),
                    const SizedBox(height: 4),
                    _team(f.awayId, f.awayTeam, favs.containsKey(f.awayId)),
                  ],
                ),
              ),
              if (f.hasScore)
                Column(
                  children: [
                    Text('${f.homeScore}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: f.isLive ? Colors.red : null)),
                    const SizedBox(height: 4),
                    Text('${f.awayScore}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: f.isLive ? Colors.red : null)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
