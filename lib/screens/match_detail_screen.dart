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
import '../services/statpal_api.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/form_spark.dart';
import '../widgets/reminder_button.dart';
import '../widgets/statpal_betting_sections.dart';
import 'compare_screen.dart';
import 'h2h_screen.dart';
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
    final adjust = ref.watch(teamAdjustProvider);
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
              ref.invalidate(statsProvider((f.leagueId, f.id)));
              ref.invalidate(fixturesProvider);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.075 : 0.045),
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.tertiary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.045 : 0.025),
            ],
          ),
        ),
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(detailProvider(f.id));
          ref.invalidate(statsProvider((f.leagueId, f.id)));
          ref.invalidate(fixturesProvider);
          await ref.read(detailProvider(f.id).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Élő meccsnél a részletek és a statisztika magától frissül.
            _LiveRefresher(leagueId: f.leagueId, fixtureId: f.id, live: f.isLive),

            // Fejléc
            Card(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.82 : 0.92),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)),
              ),
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

            // Események – profi idővonal
            if (!f.isScheduled) ...[
              _title('Események'),
              _async(detail, (dd) {
                final events = [...(dd?.events ?? const <FixtureEvent>[])]
                  ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
                if (events.isEmpty) return const Text('Még nincsenek események.');
                return _ProEventTimeline(
                  events: events,
                  homeTeam: f.homeName,
                  awayTeam: f.awayName,
                );
              }),
            ],

            // Statisztika
              _title('Statisztika'),
              _StatsSection(leagueId: f.leagueId, fixtureId: f.id),
              const SizedBox(height: 24),
            ],

            // StatPal odds-piacok és csapathiányzók
            StatPalBettingSections(key: ValueKey('${f.id}_${f.status}'), fixture: f),

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
                        h2h: h2h.valueOrNull, elo: elo, adjust: adjust);
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Részletek'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => H2HScreen(fixture: f)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Összeállítás (csak megnyitáskor tölt)
            _LineupsSection(fixtureId: f.id, home: f.homeLabel, away: f.awayLabel),
            const SizedBox(height: 16),

          ],
        ),
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
  ('possession', 'Labdabirtoklás', true),
  ('shots', 'Lövések', false),
  ('shots_on_target', 'Kapura lövés', false),
  ('blocked_shots', 'Blokkolt lövések', false),
  ('corners', 'Szögletek', false),
  ('offsides', 'Lesek', false),
  ('fouls', 'Szabálytalanságok', false),
  ('yellow_cards', 'Sárga lapok', false),
  ('red_cards', 'Piros lapok', false),
  ('total_passes', 'Passzok', false),
  ('pass_accuracy', 'Passzpontosság', true),
  ('tackles', 'Szerelések', false),
  ('tackle_success', 'Szerelés-hatékonyság', true),
  ('interceptions', 'Labdaszerzések', false),
  ('clearances', 'Felszabadítások', false),
  ('crosses', 'Beadások', false),
  ('saves', 'Védések', false),
  ('big_chances', 'Nagy helyzetek', false),
];

class _StatsSection extends ConsumerWidget {
  final int leagueId;
  final int fixtureId;
  const _StatsSection({required this.leagueId, required this.fixtureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider((leagueId, fixtureId)));
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

class _ProEventTimeline extends StatelessWidget {
  final List<FixtureEvent> events;
  final String homeTeam;
  final String awayTeam;
  const _ProEventTimeline({
    required this.events,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    int lastHalf = 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(homeTeam,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const Text("Események",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(awayTeam,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...events.expand((e) {
              final minute = int.tryParse(e.minute.replaceAll(RegExp(r'[^0-9+]'), '')) ?? 0;
              final half = minute > 45 ? 2 : 1;
              final widgets = <Widget>[];
              if (half > lastHalf) {
                widgets.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Félidő",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
                lastHalf = half;
              }
              widgets.add(_TimelineRow(event: e));
              return widgets;
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final FixtureEvent event;
  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final home = event.side == 'home';
    final accent = home ? const Color(0xFF2563EB) : const Color(0xFFDC2626);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: home ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text('${event.icon} ${event.player}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if ((event.assist ?? '').isNotEmpty || (event.detail ?? '').isNotEmpty)
            Text(
              [if ((event.assist ?? '').isNotEmpty) 'gólpassz: ${event.assist}', event.detail]
                  .where((s) => s != null && s!.isNotEmpty)
                  .join(' • '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: home ? card : const SizedBox(),
            ),
          ),
          Container(
            width: 56,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              event.minute.contains("'") ? event.minute : "${event.minute}'",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: home ? const SizedBox() : card,
            ),
          ),
        ],
      ),
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
    final total = home + away;
    final homeRatio = total > 0 ? home / total : 0.5;
    final homeLead = home > away;
    final awayLead = away > home;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(_fmt(home),
                    style: TextStyle(
                      fontWeight: homeLead ? FontWeight.w800 : FontWeight.w600,
                      color: homeLead ? const Color(0xFF2563EB) : null,
                      fontSize: 13,
                    )),
              ),
              Expanded(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              SizedBox(
                width: 50,
                child: Text(_fmt(away),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: awayLead ? FontWeight.w800 : FontWeight.w600,
                      color: awayLead ? const Color(0xFFDC2626) : null,
                      fontSize: 13,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: (homeRatio * 100).round().clamp(5, 95),
                    child: Container(color: const Color(0xFF2563EB)),
                  ),
                  Expanded(
                    flex: ((1 - homeRatio) * 100).round().clamp(5, 95),
                    child: Container(color: const Color(0xFFDC2626)),
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

// ==================== PROFI PÁLYA + ÖSSZEÁLLÍTÁS ====================
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

class _LineupsSectionState extends ConsumerState<_LineupsSection>
    with SingleTickerProviderStateMixin {
  bool _opened = false;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  int _role(LineupPlayer p) {
    final v = p.position.toLowerCase();
    if (v.contains('goal') || v.contains('keeper') || v == 'gk' ||
        v.contains('kapus')) return 0;
    if (v.contains('def') || v.contains('back') || v == 'df' ||
        v.contains('véd')) return 1;
    if (v.contains('mid') || v.contains('centre') || v.contains('wing') ||
        v == 'mf' || v.contains('közép')) return 2;
    if (v.contains('att') || v.contains('forward') || v.contains('striker') ||
        v == 'fw' || v.contains('csat')) return 3;
    return 4;
  }

  List<List<LineupPlayer>> _rows(TeamLineup lineup, {required bool reverse}) {
    final grouped = <int, List<LineupPlayer>>{
      for (var i = 0; i < 5; i++) i: <LineupPlayer>[],
    };
    for (final p in lineup.starters) {
      grouped[_role(p)]!.add(p);
    }
    final roles = reverse ? [3, 2, 1, 0, 4] : [0, 1, 2, 3, 4];
    return [
      for (final role in roles)
        if (grouped[role]!.isNotEmpty) grouped[role]!,
    ];
  }

  Widget _player(LineupPlayer p, Color accent, {required bool compact}) {
    final label = p.name.trim().isEmpty ? 'Ismeretlen' : p.name;
    return SizedBox(
      width: compact ? 66 : 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 31 : 36,
            height: compact ? 31 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF102B36).withValues(alpha: 0.96),
              border: Border.all(color: accent, width: 1.8),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.48), blurRadius: 11),
                const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              p.shirt?.toString() ?? '•',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Text(
              '${p.isCaptain ? '© ' : ''}$label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamRows(TeamLineup lineup, Color accent, {required bool reverse}) {
    final rows = _rows(lineup, reverse: reverse);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final p in row)
                  Flexible(child: _player(p, accent, compact: row.length >= 5)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _substitutes(String title, List<LineupPlayer> players, Color color) {
    if (players.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.people_alt_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const Spacer(),
            Text('${players.length} fő', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final p in players)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: color.withValues(alpha: 0.09),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${p.shirt == null ? '' : '${p.shirt} · '}${p.name}${p.isCaptain ? ' (C)' : ''}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const homeAccent = Color(0xFF20E6C5);
    const awayAccent = Color(0xFFB58CFF);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.sports_soccer),
        title: const Text('Felállás és összeállítás',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Taktikai pálya · kezdőcsapat · cserék',
            style: TextStyle(fontSize: 11)),
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (open) {
          if (open) {
            setState(() => _opened = true);
            _intro.forward(from: 0);
          }
        },
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          if (_opened)
            ref.watch(lineupsProvider(widget.fixtureId)).when(
              loading: () => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(errorText(e), style: const TextStyle(color: Colors.red)),
              ),
              data: (l) {
                if (l == null) {
                  return const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('A hivatalos összeállítás még nem érhető el ehhez a mérkőzéshez.'),
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _teamLabel(widget.away, 'VENDÉG', awayAccent)),
                        const SizedBox(width: 8),
                        Expanded(child: _teamLabel(widget.home, 'HAZAI', homeAccent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedBuilder(
                        animation: _intro,
                        builder: (context, child) => Opacity(
                          opacity: _intro.value.clamp(0.0, 1.0).toDouble(),
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - _intro.value)),
                            child: child,
                          ),
                        ),
                        child: Container(
                          height: 510,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0B503F), Color(0xFF08734F), Color(0xFF064735)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Positioned.fill(child: CustomPaint(painter: _ProPitchPainter())),
                              Positioned.fill(
                                top: 8,
                                bottom: 260,
                                left: 2,
                                right: 2,
                                child: _teamRows(l.away, awayAccent, reverse: false),
                              ),
                              Positioned.fill(
                                top: 260,
                                bottom: 8,
                                left: 2,
                                right: 2,
                                child: _teamRows(l.home, homeAccent, reverse: true),
                              ),
                              Positioned(
                                top: 9, left: 12,
                                child: _pitchTag('VENDÉG', awayAccent),
                              ),
                              Positioned(
                                bottom: 9, right: 12,
                                child: _pitchTag('HAZAI', homeAccent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(homeAccent, 'Hazai'),
                        const SizedBox(width: 18),
                        _legendDot(awayAccent, 'Vendég'),
                        const SizedBox(width: 18),
                        const Icon(Icons.stadium_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Taktikai pálya', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    _substitutes('${widget.home} · Cserék', l.home.subs, homeAccent),
                    _substitutes('${widget.away} · Cserék', l.away.subs, awayAccent),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _teamLabel(String name, String side, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(side, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _pitchTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
  );

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 5)])),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}

class _ProPitchPainter extends CustomPainter {
  const _ProPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    final outer = Rect.fromLTWH(10, 9, w - 20, h - 18);
    canvas.drawRect(outer, line);
    canvas.drawLine(Offset(10, h / 2), Offset(w - 10, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.145, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.7));

    final boxW = w * 0.62;
    final boxH = h * 0.115;
    final smallW = w * 0.34;
    final smallH = h * 0.045;
    for (final top in [true, false]) {
      final y = top ? 9.0 : h - 9 - boxH;
      final sy = top ? 9.0 : h - 9 - smallH;
      canvas.drawRect(Rect.fromLTWH((w - boxW) / 2, y, boxW, boxH), line);
      canvas.drawRect(Rect.fromLTWH((w - smallW) / 2, sy, smallW, smallH), line);
      final spotY = top ? 9 + boxH * 0.78 : h - 9 - boxH * 0.78;
      canvas.drawCircle(Offset(w / 2, spotY), 2, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (var i = 0; i < 8; i++) {
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(10 + (w - 20) * i / 8, 10, (w - 20) / 8, h - 20), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant _ProPitchPainter oldDelegate) => false;
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
            if (est.adjusted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚙ A számolásban kézi csapat-korrekció is szerepel (csapatoldal → Korrekció).',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
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
  final int leagueId;
  final int fixtureId;
  final bool live;
  const _LiveRefresher({required this.leagueId, required this.fixtureId, required this.live});

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
      ref.invalidate(statsProvider((widget.leagueId, widget.fixtureId)));
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
            const SizedBox(height: 12),
            ProbChart(
              series: liveSeries(base, events, gh, ga, minute),
              homeLabel: f.homeLabel,
              awayLabel: f.awayLabel,
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
