import '../models/fixture.dart';
import '../models/standing.dart';
import 'estimator.dart';

String _d(double v, [int n = 1]) => v.toStringAsFixed(n).replaceAll('.', ',');

/// Néhány mondatos, magyar meccs-előnézet a tabella, a forma, az egymás
/// elleni meccsek és a becslés adataiból. A csapatnevek ragozását
/// szándékosan elkerüli.
List<String> buildPreview({
  required Fixture f,
  TeamRow? home,
  TeamRow? away,
  List<Fixture>? h2h,
  MatchEstimate? est,
}) {
  final out = <String>[];
  final hn = f.homeLabel;
  final an = f.awayLabel;

  if (home != null && away != null) {
    out.add('Tabella: $hn ${home.position}. hely, ${home.points} pont '
        '(${home.played} meccs) – $an ${away.position}. hely, ${away.points} pont '
        '(${away.played} meccs).');
  }

  String formLine(String name, TeamRow? r) {
    final l = r == null ? <FormMatch>[] : r.form.where((m) => m.hasScore).toList();
    if (l.length < 3) return '';
    var w = 0, dr = 0, lo = 0, gf = 0, ga = 0;
    for (final m in l) {
      gf += m.goalsFor ?? 0;
      ga += m.goalsAgainst ?? 0;
      if (m.result == 'W') {
        w++;
      } else if (m.result == 'D') {
        dr++;
      } else {
        lo++;
      }
    }
    return 'Forma, $name: az utolsó ${l.length} meccsen $w győzelem, $dr döntetlen, '
        '$lo vereség (lőtt gól ${_d(gf / l.length)}, kapott gól ${_d(ga / l.length)} meccsenként).';
  }

  final fh = formLine(hn, home);
  final fa = formLine(an, away);
  if (fh.isNotEmpty) out.add(fh);
  if (fa.isNotEmpty) out.add(fa);

  String venueLine(String name, List<FormMatch> l, String where) {
    if (l.length < 3) return '';
    var w = 0, dr = 0, lo = 0;
    for (final m in l) {
      if (m.result == 'W') {
        w++;
      } else if (m.result == 'D') {
        dr++;
      } else {
        lo++;
      }
    }
    return '$name $where (utolsó ${l.length} meccs): $w győzelem, $dr döntetlen, $lo vereség.';
  }

  if (home != null) {
    final l = home.form.where((m) => m.hasScore && m.isHome).toList();
    final v = venueLine(hn, l, 'hazai pályán');
    if (v.isNotEmpty) out.add(v);
  }
  if (away != null) {
    final l = away.form.where((m) => m.hasScore && !m.isHome).toList();
    final v = venueLine(an, l, 'idegenben');
    if (v.isNotEmpty) out.add(v);
  }

  // Gólok: a két csapat utolsó meccsei együtt.
  final all = <FormMatch>[
    if (home != null) ...home.form.where((m) => m.hasScore),
    if (away != null) ...away.form.where((m) => m.hasScore),
  ];
  if (all.length >= 6) {
    var total = 0, over = 0, btts = 0;
    for (final m in all) {
      final t = m.totalGoals ?? 0;
      total += t;
      if (t >= 3) over++;
      if (m.bothScored) btts++;
    }
    out.add('Gólok: a két csapat utolsó ${all.length} meccsén átlagosan '
        '${_d(total / all.length)} gól esett; $over/${all.length} meccsen volt 3 vagy '
        'több gól, $btts/${all.length} meccsen szerzett mindkét csapat gólt.');
  }

  // Egymás ellen.
  if (h2h != null) {
    final done = h2h.where((m) => m.isFinished && m.hasScore).toList()
      ..sort((x, y) => y.date.compareTo(x.date));
    final last = done.take(6).toList();
    if (last.length >= 2) {
      var hw = 0, dr = 0, aw = 0, goals = 0;
      for (final m in last) {
        final ourHome = m.homeId == f.homeId;
        final gOur = ourHome ? m.homeScore! : m.awayScore!;
        final gTheir = ourHome ? m.awayScore! : m.homeScore!;
        goals += gOur + gTheir;
        if (gOur > gTheir) {
          hw++;
        } else if (gOur == gTheir) {
          dr++;
        } else {
          aw++;
        }
      }
      out.add('Egymás ellen (utolsó ${last.length}): $hn $hw győzelem, $dr döntetlen, '
          '$an $aw győzelem; átlagosan ${_d(goals / last.length)} gól.');
    }
  }

  if (est != null) {
    var best = est.home;
    var label = '$hn győzelme';
    if (est.draw > best) {
      best = est.draw;
      label = 'döntetlen';
    }
    if (est.away > best) {
      best = est.away;
      label = '$an győzelme';
    }
    out.add('Becslés: a legvalószínűbb kimenetel a(z) $label (${(best * 100).round()}%). '
        'Várható gólok: ${_d(est.lambdaHome, 2)} – ${_d(est.lambdaAway, 2)}; '
        'Over 2,5: ${(est.over25 * 100).round()}%, mindkét csapat szerez gólt: '
        '${(est.bttsYes * 100).round()}%.');
  }

  if (out.isEmpty) {
    out.add('Ehhez a meccshez még nincs elég adat az előnézethez.');
  } else {
    out.add('Ez egyszerű statisztikai összefoglaló, nem garancia és nem ajánlás.');
  }
  return out;
}
