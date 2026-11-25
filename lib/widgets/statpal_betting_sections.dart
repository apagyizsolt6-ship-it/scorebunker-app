import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../models/statpal_betting.dart';
import '../services/statpal_api.dart';
import '../providers.dart';

class StatPalBettingSections extends ConsumerStatefulWidget {
  final Fixture fixture;
  const StatPalBettingSections({super.key, required this.fixture});

  @override
  ConsumerState<StatPalBettingSections> createState() => _StatPalBettingSectionsState();
}

class _StatPalBettingSectionsState extends ConsumerState<StatPalBettingSections> {
  String _huMarket(String value) {
    final v = value.toLowerCase().replaceAll('_', ' ').trim();
    const translations = <String, String>{
      'match winner': 'Mérkőzés győztese', '1x2': '1X2', 'full time result': 'Végeredmény (1X2)',
      'total goals': 'Összes gól', 'over/under': 'Gólok száma', 'goals over under': 'Gólok száma',
      'both teams to score': 'Mindkét csapat gólt szerez', 'btts': 'Mindkét csapat gólt szerez',
      'correct score': 'Pontos eredmény', 'double chance': 'Kettős esély',
      'asian handicap': 'Ázsiai hendikep', 'handicap': 'Hendikep',
      'total corners': 'Szögletek összesen', 'corners': 'Szögletek',
      'total cards': 'Lapok összesen', 'cards': 'Lapok', 'booking points': 'Büntetőpontok',
      'half time result': 'Félidei eredmény', 'half time/full time': 'Félidő / végeredmény',
      'total shots': 'Lövések összesen', 'shots on target': 'Kapura lövések',
      'offsides': 'Lesek', 'total offsides': 'Lesek összesen', 'fouls': 'Szabálytalanságok',
    };
    return translations[v] ?? value;
  }

  String _huSelection(String value) {
    final v = value.toLowerCase().trim();
    const translations = {'home': 'Hazai', 'away': 'Vendég', 'draw': 'Döntetlen', 'yes': 'Igen', 'no': 'Nem', 'over': 'Több', 'under': 'Kevesebb'};
    return translations[v] ?? value;
  }

  String _huStatus(String value) {
    final v = value.toLowerCase().trim();
    const translations = {'injured': 'Sérült', 'injury': 'Sérülés', 'suspended': 'Eltiltott', 'suspension': 'Eltiltás', 'out': 'Nem bevethető', 'doubtful': 'Kérdéses', 'questionable': 'Kérdéses', 'unavailable': 'Nem bevethető'};
    return translations[v] ?? value;
  }
  late Future<Map<String, dynamic>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant StatPalBettingSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixture.id != widget.fixture.id || oldWidget.fixture.status != widget.fixture.status) {
      _future = _load();
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!widget.fixture.isLive) return;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  Future<Map<String, dynamic>> _safe(Future<Map<String, dynamic>> Function() request) async {
    try { return await request(); } catch (_) { return const <String, dynamic>{}; }
  }

  Future<Map<String, dynamic>> _load() async {
    final api = ref.read(apiProvider);
    if (api == null) return const {};
    final f = widget.fixture;
    final jobs = <String, Future<Map<String, dynamic>>>{};
    if (f.isLive) {
      jobs['live'] = _safe(() => api.liveOdds(f.id));
      jobs['markets'] = _safe(() => api.liveOddsMarkets(f.id));
    } else if (f.isScheduled && f.leagueId > 0) {
      jobs['prematch'] = _safe(() => api.prematchOdds(f.leagueId, f.id));
    }
    if (f.homeId > 0) jobs['homeAbsences'] = _safe(() => api.injuriesSuspensions(f.homeId));
    if (f.awayId > 0) jobs['awayAbsences'] = _safe(() => api.injuriesSuspensions(f.awayId));
    final entries = jobs.entries.toList();
    final values = await Future.wait(entries.map((e) => e.value));
    return <String, dynamic>{
      for (var i = 0; i < entries.length; i++) entries[i].key: values[i],
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final oddsRoot = widget.fixture.isLive
            ? [data['live'] ?? const {}, data['markets'] ?? const {}]
            : data['prematch'] ?? const {};
        final odds = StatPalOddsRow.parse(oddsRoot);
        final absences = [
          ...StatPalAbsence.parse(data['homeAbsences']),
          ...StatPalAbsence.parse(data['awayAbsences']),
        ];
        final markets = <String, List<StatPalOddsRow>>{};
        for (final row in odds) { (markets[_huMarket(row.market)] ??= []).add(row); }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(widget.fixture.isLive ? 'Élő oddsok és piacok' : 'Mérkőzés előtti oddsok',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: widget.fixture.isLive,
                leading: Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary),
                title: Text('Odds-piacok${odds.isEmpty ? '' : ' (${odds.length})'}'),
                subtitle: Text(widget.fixture.isLive ? 'Élő piacok • automatikus frissítés 15 mp-enként' : 'Előzetes piacok'),
                children: [
                  if (markets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('Ehhez a mérkőzéshez jelenleg nem érkezett odds-adat.'),
                    )
                  else
                    for (final entry in markets.entries)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            for (final row in entry.value)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${_huSelection(row.selection)}${row.line == null || row.line!.isEmpty ? '' : ' (${row.line})'}', style: const TextStyle(fontSize: 12))),
                                    if (row.bookmaker.isNotEmpty)
                                      Padding(padding: const EdgeInsets.only(right: 8), child: Text(row.bookmaker, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                                    Text(row.odds.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            const Divider(height: 12),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                leading: const Icon(Icons.medical_information_outlined),
                title: Text('Sérülések és eltiltások${absences.isEmpty ? '' : ' (${absences.length})'}'),
                children: [
                  if (absences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('Nincs elérhető hiányzóadat, vagy a StatPal nem közölt hiányzót.'),
                    )
                  else
                    for (final a in absences)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_off_outlined, size: 20),
                        title: Text(a.player, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([a.team, _huStatus(a.status), _huStatus(a.reason)].where((x) => x.isNotEmpty).join(' • ')),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
