import '../models/fixture.dart';
import '../models/slip.dart';
import '../models/standing.dart';
import '../models/trend.dart';

const int _minSample = 4;

List<FormMatch> _scored(TeamRow? r) =>
    r == null ? const <FormMatch>[] : r.form.where((m) => m.hasScore).toList();

int _count(List<FormMatch> l, bool Function(FormMatch) test) =>
    l.where(test).length;

/// A meccshez tartozó trendek a két csapat utolsó (max. 6) meccséből.
/// Csak az erős mintákat adja vissza.
List<Trend> trendsFor(Fixture f, TeamRow? home, TeamRow? away) {
  final hf = _scored(home);
  final af = _scored(away);
  final out = <Trend>[];

  // Közös trendek: mindkét csapat mintája összeadva.
  if (hf.length >= _minSample && af.length >= _minSample) {
    void combined(
      TrendKind kind,
      String title,
      bool Function(FormMatch) test,
      Pick pick,
      String what,
    ) {
      final hh = _count(hf, test);
      final ah = _count(af, test);
      final hits = hh + ah;
      final total = hf.length + af.length;
      if (hits / total >= 0.75) {
        out.add(Trend(
          fixture: f,
          kind: kind,
          title: title,
          detail: '${f.homeLabel}: $hh/${hf.length}, '
              '${f.awayLabel}: $ah/${af.length} meccsen $what',
          hits: hits,
          total: total,
          pick: pick,
        ));
      }
    }

    combined(TrendKind.over25, 'Over 2.5 gól',
        (m) => (m.totalGoals ?? 0) >= 3, Pick.over25, 'volt legalább 3 gól');
    combined(TrendKind.under25, 'Under 2.5 gól',
        (m) => (m.totalGoals ?? 9) <= 2, Pick.under25, 'volt legfeljebb 2 gól');
    combined(TrendKind.btts, 'Mindkét csapat szerez gólt', (m) => m.bothScored,
        Pick.bttsYes, 'szerzett gólt mindkét csapat');
  }

  // Egyedi csapat-trendek.
  void team(String name, List<FormMatch> l, Pick winPick) {
    if (l.length < _minSample) return;
    final n = l.length;

    final wins = _count(l, (m) => m.result == 'W');
    if (wins >= 4 && wins / n >= 0.67) {
      out.add(Trend(
        fixture: f,
        kind: TrendKind.win,
        title: '$name jó formában',
        detail: '$wins győzelem az utolsó $n meccsből',
        hits: wins,
        total: n,
        pick: winPick,
      ));
    }

    final unbeaten = _count(l, (m) => m.result != 'L');
    if (n >= 5 && unbeaten == n) {
      out.add(Trend(
        fixture: f,
        kind: TrendKind.unbeaten,
        title: '$name veretlen',
        detail: 'Az utolsó $n meccsén nem kapott ki',
        hits: unbeaten,
        total: n,
      ));
    }

    final scoring = _count(l, (m) => (m.goalsFor ?? 0) >= 1);
    if (n >= 5 && scoring == n) {
      out.add(Trend(
        fixture: f,
        kind: TrendKind.scoring,
        title: '$name mindig szerez gólt',
        detail: 'Az utolsó $n meccsén mindig talált be',
        hits: scoring,
        total: n,
      ));
    }

    final clean = _count(l, (m) => m.goalsAgainst == 0);
    if (clean >= 4 && clean / n >= 0.67) {
      out.add(Trend(
        fixture: f,
        kind: TrendKind.cleanSheet,
        title: '$name kapott gól nélkül',
        detail: '$clean kapott gól nélküli meccs az utolsó $n-ből',
        hits: clean,
        total: n,
      ));
    }
  }

  team(f.homeLabel, hf, Pick.home);
  team(f.awayLabel, af, Pick.away);
  return out;
}
