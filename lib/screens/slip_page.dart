import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../models/slip.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/estimate_line.dart';
import 'saved_slips_screen.dart';
import 'slip_draft_screen.dart';

enum _Scope { all, top, fav }

/// Szelvény építése: a nap összes közelgő meccse, tippel és odds-szal.
class SlipWizardPage extends ConsumerStatefulWidget {
  const SlipWizardPage({super.key});

  @override
  ConsumerState<SlipWizardPage> createState() => _SlipWizardPageState();
}

class _SlipWizardPageState extends ConsumerState<SlipWizardPage> {
  _Scope _scope = _Scope.all;
  String _q = '';

  void _openPicker(Fixture m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickSheet(fixture: m),
    );
  }

  Widget _tile(Fixture m, DraftLeg? leg) {
    final scheme = Theme.of(context).colorScheme;
    final odds = leg?.odds;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: leg != null ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        onTap: () => _openPicker(m),
        title: Text('${m.homeTeam} – ${m.awayTeam}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${leagueHu(m.leagueName)} • ${m.timeLabel}'),
        trailing: leg == null
            ? const Icon(Icons.add_circle_outline)
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(leg.pick.short,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(odds == null ? 'odds?' : fmtOdds(odds),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
      ),
    );
  }

  Widget _summary(Map<int, DraftLeg> draft) {
    final scheme = Theme.of(context).colorScheme;
    final missing = draft.values.where((l) => l.odds == null).length;
    var total = 1.0;
    for (final l in draft.values) {
      total *= l.odds ?? 1.0;
    }
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${draft.length} esemény',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      missing > 0
                          ? 'Hiányzó odds: $missing'
                          : 'Összodds: ${fmtOdds(total)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Szelvény'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SlipDraftScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyState = ref.watch(apiKeyProvider);
    final fixtures = ref.watch(liveFixturesProvider);
    final draft = ref.watch(draftProvider);
    final favIds = ref.watch(favoritesProvider).keys.toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szelvény'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mentett szelvények',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedSlipsScreen()),
            ),
          ),
        ],
      ),
      body: keyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (k) {
          if (k == null || k.isEmpty) return const NoKeyView();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Keresés: csapat vagy bajnokság',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    ChoiceChip(
                      label: const Text('Összes meccs'),
                      selected: _scope == _Scope.all,
                      onSelected: (_) => setState(() => _scope = _Scope.all),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Top ligák'),
                      selected: _scope == _Scope.top,
                      onSelected: (_) => setState(() => _scope = _Scope.top),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Kedvencek'),
                      selected: _scope == _Scope.fav,
                      onSelected: (_) => setState(() => _scope = _Scope.fav),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: fixtures.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(fixturesProvider),
                  ),
                  data: (list) {
                    final q = _q.trim().toLowerCase();
                    final open = list.where((m) {
                      if (!m.isScheduled) return false;
                      final scopeOk = switch (_scope) {
                        _Scope.all => true,
                        _Scope.top => topLeagueOf(m) != null,
                        _Scope.fav => favIds.contains(m.homeId) ||
                            favIds.contains(m.awayId),
                      };
                      if (!scopeOk) return false;
                      if (q.isEmpty) return true;
                      final hay =
                          '${m.homeTeam} ${m.awayTeam} ${m.leagueName} ${leagueHu(m.leagueName)}'
                              .toLowerCase();
                      return hay.contains(q);
                    }).toList()
                      ..sort(byKickoff);
                    if (open.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nincs kiválasztható meccs.\n'
                            'A Meccsek fülön válassz másik napot, vagy módosítsd a szűrést.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: open.length,
                      itemBuilder: (context, i) =>
                          _tile(open[i], draft[open[i].id]),
                    );
                  },
                ),
              ),
              if (draft.isNotEmpty) _summary(draft),
            ],
          );
        },
      ),
    );
  }
}

// ==================== TIPP + ODDS VÁLASZTÓ ====================
class _PickSheet extends ConsumerStatefulWidget {
  final Fixture fixture;
  const _PickSheet({required this.fixture});

  @override
  ConsumerState<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends ConsumerState<_PickSheet> {
  Pick? _pick;
  late final TextEditingController _odds;
  String? _error;

  @override
  void initState() {
    super.initState();
    final leg = ref.read(draftProvider)[widget.fixture.id];
    _pick = leg?.pick;
    final o = leg?.odds;
    _odds = TextEditingController(text: o == null ? '' : o.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _odds.dispose();
    super.dispose();
  }

  double? _oddsValue() {
    final v = double.tryParse(_odds.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 1.0) ? null : v;
  }

  void _save() {
    final pick = _pick;
    if (pick == null) return;
    final txt = _odds.text.trim().replaceAll(',', '.');
    final odds = txt.isEmpty ? null : double.tryParse(txt);
    if (txt.isNotEmpty && (odds == null || odds <= 1.0)) {
      setState(() => _error = 'Az odds legyen 1,00-nál nagyobb szám.');
      return;
    }
    ref.read(draftProvider.notifier).set(widget.fixture, pick, odds);
    Navigator.pop(context);
  }

  Widget _group(String title, List<Pick> picks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in picks)
              ChoiceChip(
                label: Text(p.short),
                selected: _pick == p,
                onSelected: (_) => setState(() => _pick = p),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final exists = ref.watch(draftProvider).containsKey(f.id);
    final est = ref
        .watch(estimateProvider((f.leagueId, f.homeId, f.awayId)))
        .valueOrNull;
    final pick = _pick;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.homeTeam} – ${f.awayTeam}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${leagueHu(f.leagueName)} • ${f.timeLabel}',
                style: const TextStyle(fontSize: 12)),
            _group('Kimenetel', const [Pick.home, Pick.draw, Pick.away]),
            _group('Gólok', const [Pick.over25, Pick.under25]),
            _group('Mindkét csapat szerez gólt', const [Pick.bttsYes, Pick.bttsNo]),
            if (est != null && pick != null) ...[
              const SizedBox(height: 12),
              EstimateLine(prob: est.prob(pick), odds: _oddsValue()),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _odds,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Odds (a fogadóirodától, pl. 1,85)',
                errorText: _error,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (exists)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(draftProvider.notifier).remove(f.id);
                        Navigator.pop(context);
                      },
                      child: const Text('Eltávolítás'),
                    ),
                  ),
                if (exists) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _pick == null ? null : _save,
                    child: Text(exists ? 'Frissítés' : 'Szelvényre'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
