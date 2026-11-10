import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../models/live_score.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'leagues_screen.dart';
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
  final bool isPin;
  final bool isFollow;
  final Map<String, List<Fixture>> leagues = {};

  _Group(this.key, this.title, this.geo, this.isTop,
      {this.isFav = false, this.isPin = false, this.isFollow = false});

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

class _HiddenNote {
  final int count;
  const _HiddenNote(this.count);
}

List<_Group> _groupFixtures(
  List<Fixture> list,
  Set<int> favIds,
  Set<int> pinned,
  Set<int> followed,
) {
  final tops = <String, _Group>{};
  final countries = <String, _Group>{};
  _Group? fav;
  _Group? pin;
  _Group? follow;

  for (final m in list) {
    if (followed.contains(m.id)) {
      final fo = follow ??=
          _Group('follow', 'Követett meccsek', '', true, isFollow: true);
      fo.leagues.putIfAbsent(m.leagueName, () => []).add(m);
    }
    if (favIds.contains(m.homeId) || favIds.contains(m.awayId)) {
      final fg = fav ??= _Group('fav', 'Kedvenceim', '', true, isFav: true);
      fg.leagues.putIfAbsent(m.leagueName, () => []).add(m);
    }
    if (pinned.contains(m.leagueId)) {
      final pg = pin ??=
          _Group('pin', 'Kiemelt bajnokságaim', '', true, isPin: true);
      pg.leagues.putIfAbsent(m.leagueName, () => []).add(m);
      continue;
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
  final pinGroup = pin;
  final followGroup = follow;
  return [
    if (followGroup != null) followGroup,
    if (favGroup != null) favGroup,
    if (pinGroup != null) pinGroup,
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

    final lp = ref.watch(leaguePrefsProvider);
    final followed = ref.watch(followedProvider);
    final visibleAll = [
      for (final m in all)
        if (!lp.hidden.contains(m.leagueId)) m,
    ];

    final liveCount = visibleAll.where((m) => m.isLive).length;
    final allKeys =
        _groupFixtures(visibleAll, favIds, lp.pinned, followed)
            .map((g) => g.key)
            .toSet();
    final allCollapsed = allKeys.isNotEmpty && allKeys.every(collapsed.contains);

    return Scaffold(
      appBar: AppBar(
        title: const Text('APISCORES'),
        centerTitle: true,
        actions: [
          const _LiveDot(),
          IconButton(
            tooltip: 'Bajnokság-szűrő',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaguesScreen()),
            ),
          ),
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
          preferredSize: Size.fromHeight(64),
          child: _DateBar(),
        ),
      ),
      body: _SwipeDays(
        child: keyState.when(
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
                    final visible = [
                      for (final m in list)
                        if (!lp.hidden.contains(m.leagueId)) m,
                    ];
                    final hiddenCount = list.length - visible.length;
                    final filtered = _applyFilter(
                      _applySearch(visible, query),
                      filter,
                      favOnly,
                      favIds,
                    );
                    if (filtered.isEmpty) {
                      String msg = 'Nincs találat.';
                      if (list.isEmpty) {
                        msg = 'Nincs meccs ezen a napon.';
                      } else if (visible.isEmpty && hiddenCount > 0) {
                        msg =
                            '$hiddenCount meccs el van rejtve a bajnokság-szűrő miatt.';
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
                    final groups =
                        _groupFixtures(filtered, favIds, lp.pinned, followed);
                    // Keresés közben mindent mutatunk.
                    final hidden =
                        query.trim().isEmpty ? collapsed : <String>{};

                    final items = <Object>[];
                    var topLabel = false;
                    var countryLabel = false;
                    for (final g in groups) {
                      if (!g.isFav &&
                          !g.isPin &&
                          !g.isFollow &&
                          g.isTop &&
                          !topLabel) {
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

                    if (hiddenCount > 0 && query.trim().isEmpty) {
                      items.add(_HiddenNote(hiddenCount));
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
                          if (item is _HiddenNote) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                icon: const Icon(
                                    Icons.visibility_off_outlined, size: 18),
                                label: Text(
                                    '${item.count} meccs el van rejtve a bajnokság-szűrő miatt'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LeaguesScreen(),
                                  ),
                                ),
                              ),
                            );
                          }
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
      ),
    );
  }
}

/// Vízszintes húzásra (balra / jobbra) egy napot lép előre / vissza.
class _SwipeDays extends ConsumerWidget {
  final Widget child;
  const _SwipeDays({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 500) return;
        final cur = ref.read(selectedDateProvider);
        final delta = v < 0 ? 1 : -1;
        ref.read(selectedDateProvider.notifier).state =
            DateTime(cur.year, cur.month, cur.day + delta);
      },
      child: child,
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
        color: group.isFollow
            ? scheme.secondaryContainer.withValues(alpha: 0.7)
            : group.isFav
            ? Colors.amber.withValues(alpha: 0.22)
            : group.isPin
                ? scheme.tertiaryContainer.withValues(alpha: 0.6)
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
                Text(
                    group.isFollow
                        ? '👁'
                        : (group.isFav
                            ? '⭐'
                            : (group.isPin ? '📌' : _flagFor(group.geo))),
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

/// Napsáv: a kiválasztott nap körül ±3 nap, koppintással váltható.
class _DateBar extends ConsumerWidget {
  const _DateBar();

  static const _weekdays = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(selectedDateProvider);
    final scheme = Theme.of(context).colorScheme;
    void setDate(DateTime x) =>
        ref.read(selectedDateProvider.notifier).state = x;
    final now = DateTime.now();
    bool isToday(DateTime x) =>
        x.year == now.year && x.month == now.month && x.day == now.day;

    final days = [
      for (var i = -3; i <= 3; i++) DateTime(d.year, d.month, d.day + i),
    ];

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (final x in days)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setDate(x),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 6),
                        decoration: BoxDecoration(
                          color: x.day == d.day && x.month == d.month
                              ? scheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isToday(x)
                              ? Border.all(color: scheme.primary, width: 1.2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekdays[x.weekday - 1],
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${x.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    x.day == d.day && x.month == d.month
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '${DateFormat('yyyy.MM.dd').format(d)} – dátum választása',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: d,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (p != null) setDate(p);
            },
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
