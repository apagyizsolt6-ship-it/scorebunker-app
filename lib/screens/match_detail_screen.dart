import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/league_catalog.dart';
import '../models/calibration.dart';
import '../models/fixture.dart';
import '../models/match_extras.dart';
import '../models/standing.dart';
import '../providers.dart';
import '../services/estimator.dart';
import '../services/preview.dart';
import '../services/sport_api.dart';
import '../widgets/common.dart';
import '../widgets/form_spark.dart';
import '../widgets/reminder_button.dart';
import 'compare_screen.dart';
import 'standings_screen.dart';
import 'team_screen.dart';

class MatchDetailScreen extends ConsumerWidget {
  final Fixture fixture;

  const MatchDetailScreen({super.key, required this.fixture});

  Widget _async<T>(AsyncValue<T> v, Widget Function(T) builder) {
    return v.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Text(errorText(e), style: const TextStyle(color: Colors.red)),
      data: builder,
    );
  }

  String _leagueTitle(Fixture f) {
    final top = topLeagueOf(f);
    final name = top != null ? top.nameHu : leagueHu(f.leagueName);
    if (top != null || f.leagueZone.isEmpty) return name;
    return '${countryHu(f.leagueZone)} • $name';
  }

  String _statusText(Fixture f) {
    switch (f.status) {
      case 'Scheduled':
        if (f.kickoff == null) return 'Kezdés: ${f.date}';
        return DateFormat('yyyy.MM.dd HH:mm').format(f.kickoff!);
      case 'LIVE':
        return f.minute == 'HT' ? 'Félidő' : "Élő ${f.minute ?? ''}".trim();
      case 'FT':
        return 'Vége';
      case 'AET':
        return 'Vége (hosszabbítás után)';
      case 'PENS':
        return 'Vége (tizenegyesekkel)';
      case 'Postponed':
        return 'Elhalasztva';
      case 'Cancelled':
        return 'Törölve';
      case 'Suspended':
        return 'Felfüggesztve';
      default:
        return f.status;
    }
  }

  /// A listában élő frissített állapot, különben a megnyitáskori meccs.
  Fixture _current(WidgetRef ref) {
    final list = ref.watch(liveFixturesProvider).valueOrNull;
    if (list != null) {
      for (final x in list) {
        if (x.id == fixture.id) return x;
      }
    }
    return fixture;
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = _current(ref);
    final detail = ref.watch(detailProvider(f.id));
    final standings = ref.watch(standingsProvider(f.leagueId));
    final h2h = ref.watch(h2hProvider((f.homeId, f.awayId)));
    final favs = ref.watch(favoritesProvider);
    final calib = ref.watch(calibrationProvider);
    final elo = ref.watch(eloProvider);
    final following = ref.watch(followedProvider).contains(f.id);
    final d = detail.valueOrNull;

    void toggleFav(int id, String name) =>
        ref.read(favoritesProvider.notifier).toggle(id, name);

    return Scaffold(
      appBar: AppBar(
        title: Text('${f.homeLabel} – ${f.awayLabel}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          if (!f.isFinished)
            IconButton(
              tooltip: following
                  ? 'Követés vége'
                  : 'Követem (a Meccsek lista tetején marad)',
              icon: Icon(
                following ? Icons.push_pin : Icons.push_pin_outlined,
                color: following ? Colors.amber : null,
              ),
              onPressed: () =>
                  ref.read(followedProvider.notifier).toggle(f.id),
            ),
          ReminderButton(fixture: f),
          IconButton(
            tooltip: 'Frissítés',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(detailProvider(f.id));
              ref.invalidate(statsProvider(f.id));
              ref.invalidate(fixturesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(detailProvider(f.id));
          ref.invalidate(statsProvider(f.id));
          ref.invalidate(fixturesProvider);
          await ref.read(detailProvider(f.id).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Élő meccsnél a részletek és a statisztika magától frissül.
            _LiveRefresher(fixtureId: f.id, live: f.isLive),

            // Fejléc
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _leagueTitle(f),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText(f),
                      style: TextStyle(
                        fontSize: 13,
                        color: f.isLive ? Colors.red : null,
                        fontWeight: f.isLive ? FontWeight.bold : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TeamBlock(
                            id: f.homeId,
                            name: f.homeTeam,
                            isFav: favs.containsKey(f.homeId),
                            onToggle: () => toggleFav(f.homeId, f.homeTeam),
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamScreen(
                                    teamId: f.homeId, name: f.homeTeam),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            f.hasScore ? '${f.homeScore} - ${f.awayScore}' : 'VS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: f.isLive ? Colors.red : null,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TeamBlock(
                            id: f.awayId,
                            name: f.awayTeam,
                            isFav: favs.containsKey(f.awayId),
                            onToggle: () => toggleFav(f.awayId, f.awayTeam),
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamScreen(
                                    teamId: f.awayId, name: f.awayTeam),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (d != null && d.hasHalfTime && !f.isScheduled) ...[
                      const SizedBox(height: 4),
                      Text('Félidő: ${d.htHome} - ${d.htAway}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    if (f.penaltyHome != null && f.penaltyAway != null) ...[
                      const SizedBox(height: 4),
                      Text('Tizenegyesek: ${f.penaltyHome} - ${f.penaltyAway}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    if (d != null && d.homeStadium.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        d.homeCity.isEmpty
                            ? '🏟 ${d.homeStadium}'
                            : '🏟 ${d.homeStadium}, ${d.homeCity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (d != null &&
                        (d.homeCoach.isNotEmpty || d.awayCoach.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Edzők: ${d.homeCoach.isEmpty ? '–' : d.homeCoach}'
                        '  |  ${d.awayCoach.isEmpty ? '–' : d.awayCoach}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Események
            if (!f.isScheduled) ...[
              _title('Események'),
              _async(detail, (dd) {
                final events = [...(dd?.events ?? const <FixtureEvent>[])]
                  ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
                if (events.isEmpty) return const Text('Nincs esemény.');
                final scheme = Theme.of(context).colorScheme;
                // Idővonal: középen a perc, a hazai események balra, a vendégek jobbra.
                return Column(
                  children: events.map((e) {
                    final home = e.side == 'home';
                    final text = Text('${e.icon} ${e.player}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: home ? text : const SizedBox(),
                            ),
                          ),
                          Container(
                            width: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.minute,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: home ? const SizedBox() : text,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 24),

              // Statisztika
              _title('Statisztika'),
              _StatsSection(fixtureId: f.id),
              const SizedBox(height: 24),
            ],

            // Tabella + forma (egy hívásból)
            standings.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (t) {
                final home = t.rowOf(f.homeId);
                final away = t.rowOf(f.awayId);
                if (home == null && away == null) return const SizedBox.shrink();
                final rawEst = f.isFinished
                    ? null
                    : estimateMatch(t, f.homeId, f.awayId,
                        h2h: h2h.valueOrNull, elo: elo);
                final est =
                    rawEst == null ? null : calibrateEstimate(rawEst, calib);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Tabella'),
                    _TableCard(home: home, away: away),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.compare_arrows, size: 18),
                            label: const Text('Összehasonlítás'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompareScreen(fixture: f),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.leaderboard_outlined,
                                size: 18),
                            label: const Text('Teljes tabella'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StandingsScreen(
                                  leagueId: f.leagueId,
                                  title: leagueHu(f.leagueName),
                                  highlight: {f.homeId, f.awayId},
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (f.isLive && rawEst != null) ...[
                      const SizedBox(height: 16),
                      _title('Élő esély'),
                      _LiveProbCard(
                        fixture: f,
                        base: rawEst,
                        events: d?.events ?? const <FixtureEvent>[],
                      ),
                    ],
                    if (est != null) ...[
                      const SizedBox(height: 16),
                      _title('Becsült esélyek'),
                      _EstimateCard(
                        est: est,
                        home: f.homeLabel,
                        away: f.awayLabel,
                      ),
                    ],
                    if (!f.isFinished) ...[
                      const SizedBox(height: 16),
                      _title('Meccs-előnézet'),
                      _PreviewCard(
                        lines: buildPreview(
                          f: f,
                          home: home,
                          away: away,
                          h2h: h2h.valueOrNull,
                          est: est,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _title('Forma (utolsó meccsek)'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _FormColumn(
                                f.homeLabel, home?.form ?? const [])),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _FormColumn(
                                f.awayLabel, away?.form ?? const [])),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // H2H
            _title('Egymás ellen (utolsó 6)'),
            _async(h2h, (list) {
              final done = list.where((m) => m.isFinished && m.hasScore).toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              final last = done.take(6).toList();
              if (last.isEmpty) {
                return const Text('Nincs korábbi egymás elleni meccs.');
              }
              int hw = 0, dr = 0, aw = 0;
              for (final m in last) {
                if (m.homeScore == m.awayScore) {
                  dr++;
                } else {
                  final winnerId =
                      m.homeScore! > m.awayScore! ? m.homeId : m.awayId;
                  if (winnerId == f.homeId) {
                    hw++;
                  } else {
                    aw++;
                  }
                }
              }
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _H2HBox('$hw', 'Hazai győzelem'),
                      _H2HBox('$dr', 'Döntetlen'),
                      _H2HBox('$aw', 'Vendég győzelem'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...last.map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${m.date}  ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Összeállítás (csak megnyitáskor tölt)
            _LineupsSection(fixtureId: f.id, home: f.homeLabel, away: f.awayLabel),
            const SizedBox(height: 16),

            // Szöglet megjegyzés
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Szöglet-statisztikát a SportAPI nem szolgáltat, ezért itt nem jelenik meg.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FEJLÉC: CSAPAT + CSILLAG ====================
class _TeamBlock extends StatelessWidget {
  final int id;
  final String name;
  final bool isFav;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _TeamBlock({
    required this.id,
    required this.name,
    required this.isFav,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                TeamLogo(teamId: id, size: 40, padRight: false),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: isFav ? 'Eltávolítás a kedvencekből' : 'Kedvencnek jelölöm',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isFav ? Icons.star : Icons.star_border,
            color: isFav ? Colors.amber : null,
          ),
          onPressed: onToggle,
        ),
      ],
    );
  }
}

// ==================== STATISZTIKA ====================
const List<(String, String, bool)> _statRows = [
  ('shots', 'Lövések', false),
  ('shots_on_target', 'Kapura lövés', false),
  ('fouls', 'Szabálytalanságok', false),
  ('total_passes', 'Passzok', false),
  ('pass_accuracy', 'Passzpontosság', true),
  ('tackles', 'Szerelések', false),
  ('tackle_success', 'Szerelés-hatékonyság', true),
  ('saves', 'Védések', false),
  ('yellow_cards', 'Sárga lapok', false),
];

class _StatsSection extends ConsumerWidget {
  final int fixtureId;
  const _StatsSection({required this.fixtureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider(fixtureId));
    return stats.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Text(errorText(e), style: const TextStyle(color: Colors.red)),
      data: (s) {
        if (s == null) {
          return const Text('Ehhez a meccshez még nincs elérhető statisztika.');
        }
        final rows = <Widget>[];
        for (final r in _statRows) {
          final h = s.home[r.$1];
          final a = s.away[r.$1];
          if (h == null && a == null) continue;
          rows.add(_StatBar(
            label: r.$2,
            home: h ?? 0,
            away: a ?? 0,
            percent: r.$3,
          ));
        }
        if (rows.isEmpty) {
          return const Text('Ehhez a meccshez még nincs elérhető statisztika.');
        }
        return Column(children: rows);
      },
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final num home;
  final num away;
  final bool percent;

  const _StatBar({
    required this.label,
    required this.home,
    required this.away,
    required this.percent,
  });

  String _fmt(num v) {
    final t = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return percent ? '$t%' : t;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hFlex = math.max(1, (home * 10).round());
    final aFlex = math.max(1, (away * 10).round());
    final hLead = home >= away;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(_fmt(home),
                style: TextStyle(
                    fontWeight: hLead ? FontWeight.bold : FontWeight.w500)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      flex: hFlex,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: aFlex,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(_fmt(away),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: hLead ? FontWeight.w500 : FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ==================== TABELLA ====================
class _TableCard extends StatelessWidget {
  final TeamRow? home;
  final TeamRow? away;
  const _TableCard({required this.home, required this.away});

  Widget _row(TeamRow? r, String fallback) {
    if (r == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$fallback: nincs tabella-adat',
            style: const TextStyle(fontSize: 12)),
      );
    }
    final gd = r.goalDiff >= 0 ? '+${r.goalDiff}' : '${r.goalDiff}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${r.position}.',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '${r.played} m  ${r.won}-${r.draw}-${r.lost}  $gd',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 10),
          Text('${r.points} p',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            _row(home, 'Hazai'),
            const Divider(height: 1),
            _row(away, 'Vendég'),
          ],
        ),
      ),
    );
  }
}

// ==================== FORMA ====================
class _FormColumn extends StatelessWidget {
  final String team;
  final List<FormMatch> form;
  const _FormColumn(this.team, this.form);

  String _label(String r) {
    switch (r) {
      case 'W':
        return 'Gy';
      case 'D':
        return 'D';
      case 'L':
        return 'V';
      default:
        return r;
    }
  }

  String _shortDate(String d) =>
      d.length >= 10 ? '${d.substring(5, 7)}.${d.substring(8, 10)}.' : d;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(team,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        if (form.isEmpty)
          const Text('–')
        else ...[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: form.map((m) {
              final color = m.result == 'W'
                  ? Colors.green
                  : (m.result == 'D' ? Colors.grey : Colors.red);
              return Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(_label(m.result),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          FormSpark(form: form),
          const SizedBox(height: 8),
          for (final m in form.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                '${_shortDate(m.date)} ${m.isHome ? 'vs' : '@'} ${m.opponent}  '
                '${m.homeScore ?? '-'}-${m.awayScore ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }
}

class _H2HBox extends StatelessWidget {
  final String value;
  final String label;
  const _H2HBox(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ==================== ÖSSZEÁLLÍTÁS ====================
class _LineupsSection extends ConsumerStatefulWidget {
  final int fixtureId;
  final String home;
  final String away;
  const _LineupsSection({
    required this.fixtureId,
    required this.home,
    required this.away,
  });

  @override
  ConsumerState<_LineupsSection> createState() => _LineupsSectionState();
}

class _LineupsSectionState extends ConsumerState<_LineupsSection> {
  bool _opened = false;

  Widget _team(String name, TeamLineup l) {
    Widget player(LineupPlayer p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(p.shirt?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Text(
                  p.isCaptain ? '${p.name} (C)' : p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        ...l.starters.map(player),
        if (l.subs.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Cserék',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          ...l.subs.map(player),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('Összeállítás',
            style: TextStyle(fontWeight: FontWeight.bold)),
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (open) {
          if (open && !_opened) setState(() => _opened = true);
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_opened)
            ref.watch(lineupsProvider(widget.fixtureId)).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(errorText(e),
                      style: const TextStyle(color: Colors.red)),
                  data: (l) {
                    if (l == null) {
                      return const Text(
                          'Az összeállítás még nem elérhető ehhez a meccshez.');
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _team(widget.home, l.home)),
                        const SizedBox(width: 12),
                        Expanded(child: _team(widget.away, l.away)),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}

// ==================== BECSÜLT ESÉLYEK ====================
class _EstimateCard extends StatelessWidget {
  final MatchEstimate est;
  final String home;
  final String away;
  const _EstimateCard({
    required this.est,
    required this.home,
    required this.away,
  });

  Widget _row(BuildContext context, String label, double p) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              '${(p * 100).round()}%  (${fairOdds(p).toStringAsFixed(2)})',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Várható gólok: ${est.lambdaHome.toStringAsFixed(2)} – '
              '${est.lambdaAway.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _row(context, '$home nyer', est.home),
            _row(context, 'Döntetlen', est.draw),
            _row(context, '$away nyer', est.away),
            const Divider(height: 16),
            _row(context, 'Over 2.5 gól', est.over25),
            _row(context, 'Under 2.5 gól', est.under25),
            const Divider(height: 16),
            _row(context, 'Mindkét csapat lő', est.bttsYes),
            _row(context, 'Nem lő mindkettő', est.bttsNo),
            const SizedBox(height: 8),
            const Text(
              'Zárójelben a fair odds (jutalék nélkül). Egyszerű becslés a '
              'bajnokság eredményeiből, a hazai/idegenbeli formából és az '
              'egymás elleni meccsekből. Nem garancia és nem ajánlás.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ÉLŐ AUTOMATIKUS FRISSÍTÉS ====================
/// Élő meccsnél 45 másodpercenként újratölti az eseményeket és a statisztikát.
class _LiveRefresher extends ConsumerStatefulWidget {
  final int fixtureId;
  final bool live;
  const _LiveRefresher({required this.fixtureId, required this.live});

  @override
  ConsumerState<_LiveRefresher> createState() => _LiveRefresherState();
}

class _LiveRefresherState extends ConsumerState<_LiveRefresher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _LiveRefresher old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.live) return;
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      ref.invalidate(detailProvider(widget.fixtureId));
      ref.invalidate(statsProvider(widget.fixtureId));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ==================== ÉLŐ ESÉLY ====================
class _LiveProbCard extends StatelessWidget {
  final Fixture fixture;
  final MatchEstimate base;
  final List<FixtureEvent> events;
  const _LiveProbCard({
    required this.fixture,
    required this.base,
    required this.events,
  });

  String _p(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final gh = f.homeScore ?? 0;
    final ga = f.awayScore ?? 0;
    final minute = parseMinute(f.minute) ?? 0;
    final live = liveEstimate(base, gh, ga, minute);
    final steps = liveTimeline(base, events, gh, ga);
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, double v) => Expanded(
          child: Column(
            children: [
              Text(_p(v),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Állás: $gh – $ga${f.minute == null ? '' : ' • ${f.minute}'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                chip('${f.homeLabel} nyer', live.home),
                chip('Döntetlen', live.draw),
                chip('${f.awayLabel} nyer', live.away),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Over 2,5: ${_p(live.over25)}  •  mindkét csapat szerez gólt: ${_p(live.bttsYes)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Hátralévő várható gólok: ${live.lambdaHome.toStringAsFixed(2)} – ${live.lambdaAway.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            if (steps.length >= 2) ...[
              const Divider(height: 20),
              const Text('Hogyan változott az esély',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final st in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    st.minute == 0 && st.home == 0 && st.away == 0
                        ? "Kezdés: 1 ${_p(st.est.home)} • X ${_p(st.est.draw)} • 2 ${_p(st.est.away)}"
                        : "${st.minute}' (${st.home}–${st.away}): 1 ${_p(st.est.home)} • X ${_p(st.est.draw)} • 2 ${_p(st.est.away)}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Az alapbecslés és az eltelt idő alapján számolva (nem veszi figyelembe a lapokat és a cseréket).',
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MECCS-ELŐNÉZET ====================
class _PreviewCard extends StatelessWidget {
  final List<String> lines;
  const _PreviewCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 8),
                child: Text('• $l', style: const TextStyle(fontSize: 13)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Másolás'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: lines.join('\n')));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                        content: Text('Az előnézet a vágólapra került.')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
