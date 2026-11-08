import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/slip.dart';
import '../providers.dart';
import '../services/estimator.dart';
import '../widgets/estimate_line.dart';

/// A most épített szelvény: odds-ok szerkesztése, tét, várható nyeremény, mentés.
class SlipDraftScreen extends ConsumerStatefulWidget {
  const SlipDraftScreen({super.key});

  @override
  ConsumerState<SlipDraftScreen> createState() => _SlipDraftScreenState();
}

class _SlipDraftScreenState extends ConsumerState<SlipDraftScreen> {
  final TextEditingController _stake = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _stake.dispose();
    _name.dispose();
    super.dispose();
  }

  double? get _stakeValue {
    final v = double.tryParse(_stake.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  void _save(Map<int, DraftLeg> draft) {
    final stake = _stakeValue;
    if (stake == null || draft.isEmpty) return;
    for (final l in draft.values) {
      if (l.odds == null || l.odds! <= 1.0) return;
    }
    final now = DateTime.now();
    final name = _name.text.trim().isEmpty
        ? 'Szelvény ${now.month.toString().padLeft(2, '0')}.'
            '${now.day.toString().padLeft(2, '0')}. '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
        : _name.text.trim();
    final slip = Slip(
      id: now.millisecondsSinceEpoch,
      name: name,
      stake: stake,
      createdAt: now,
      legs: [
        for (final l in draft.values)
          SlipLeg(
            fixtureId: l.fixture.id,
            home: l.fixture.homeTeam,
            away: l.fixture.awayTeam,
            league: leagueHu(l.fixture.leagueName),
            date: l.fixture.date,
            kickoff: l.fixture.kickoff,
            pick: l.pick,
            odds: l.odds!,
          ),
      ],
    );
    ref.read(slipsProvider.notifier).add(slip);
    ref.read(draftProvider.notifier).clear();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Szelvény elmentve. A Mentett szelvényeknél követheted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider);
    final scheme = Theme.of(context).colorScheme;

    final allOdds = draft.values.every((l) => l.odds != null && l.odds! > 1.0);
    var total = 1.0;
    for (final l in draft.values) {
      total *= l.odds ?? 1.0;
    }
    final stake = _stakeValue;
    final canSave = draft.isNotEmpty && allOdds && stake != null;

    // Becsült együttes esély (a meccseket függetlennek tekintve).
    var combined = 1.0;
    var haveAllEstimates = draft.isNotEmpty;
    for (final l in draft.values) {
      final est = ref
          .watch(estimateProvider(
              (l.fixture.leagueId, l.fixture.homeId, l.fixture.awayId)))
          .valueOrNull;
      if (est == null) {
        haveAllEstimates = false;
      } else {
        combined *= est.prob(l.pick);
      }
    }
    final comboEv = (haveAllEstimates && allOdds)
        ? expectedValue(combined, total)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szelvény'),
        centerTitle: true,
        actions: [
          if (draft.isNotEmpty)
            IconButton(
              tooltip: 'Szelvény törlése',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(draftProvider.notifier).clear(),
            ),
        ],
      ),
      body: draft.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Üres a szelvény.\nVálassz meccseket a Szelvény fülön, '
                  'vagy tedd rá a Trendek kártyáiról.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in draft.values)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l.fixture.homeTeam} – ${l.fixture.awayTeam}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l.pick.long} • ${l.fixture.timeLabel}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant),
                                ),
                                _LegEstimate(leg: l),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 78,
                            child: _OddsField(
                              key: ValueKey('odds_${l.fixture.id}'),
                              initial: l.odds,
                              onChanged: (v) => ref
                                  .read(draftProvider.notifier)
                                  .setOdds(l.fixture.id, v),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eltávolítás',
                            icon: const Icon(Icons.close),
                            onPressed: () => ref
                                .read(draftProvider.notifier)
                                .remove(l.fixture.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _stake,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Tét',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Szelvény neve (nem kötelező)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SumRow('Események', '${draft.length}'),
                        _SumRow('Összodds',
                            allOdds ? fmtOdds(total) : 'adj meg minden oddsot'),
                        _SumRow('Tét', stake == null ? '–' : fmtAmount(stake)),
                        if (haveAllEstimates) ...[
                          _SumRow('Becsült együttes esély',
                              '${(combined * 100).toStringAsFixed(1)}%'),
                          _SumRow('Fair összodds', fmtOdds(fairOdds(combined))),
                          if (comboEv != null)
                            _SumRow(
                              'Becsült várható érték',
                              '${comboEv >= 0 ? '+' : ''}${(comboEv * 100).toStringAsFixed(0)}%',
                            ),
                        ],
                        const Divider(),
                        _SumRow(
                          'Várható nyeremény',
                          (allOdds && stake != null)
                              ? fmtAmount(stake * total)
                              : '–',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (haveAllEstimates)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A becslés egyszerű statisztikai modell a bajnokság '
                      'gólátlagaiból, a meccseket függetlennek tekinti. '
                      'Nem garancia és nem ajánlás.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Szelvény mentése'),
                  onPressed: canSave ? () => _save(draft) : null,
                ),
                if (!canSave)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A mentéshez minden tipphez kell odds (1,00 felett) és tét.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SumRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _OddsField extends StatefulWidget {
  final double? initial;
  final ValueChanged<double?> onChanged;
  const _OddsField({super.key, required this.initial, required this.onChanged});

  @override
  State<_OddsField> createState() => _OddsFieldState();
}

class _OddsFieldState extends State<_OddsField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final o = widget.initial;
    _c = TextEditingController(text: o == null ? '' : o.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: 'odds',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (t) {
        final v = double.tryParse(t.trim().replaceAll(',', '.'));
        widget.onChanged(v);
      },
    );
  }
}

class _LegEstimate extends ConsumerWidget {
  final DraftLeg leg;
  const _LegEstimate({required this.leg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = leg.fixture;
    final est =
        ref.watch(estimateProvider((f.leagueId, f.homeId, f.awayId))).valueOrNull;
    if (est == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: EstimateLine(
        prob: est.prob(leg.pick),
        odds: leg.odds,
        fontSize: 11,
      ),
    );
  }
}
