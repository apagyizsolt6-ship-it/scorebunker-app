import 'fixture.dart';

/// Egy tipp típusa egy meccsen.
enum Pick { home, draw, away, over25, under25, bttsYes, bttsNo }

extension PickX on Pick {
  String get short => switch (this) {
        Pick.home => '1',
        Pick.draw => 'X',
        Pick.away => '2',
        Pick.over25 => 'Over 2.5',
        Pick.under25 => 'Under 2.5',
        Pick.bttsYes => 'BTTS igen',
        Pick.bttsNo => 'BTTS nem',
      };

  String get long => switch (this) {
        Pick.home => 'Hazai győzelem',
        Pick.draw => 'Döntetlen',
        Pick.away => 'Vendég győzelem',
        Pick.over25 => 'Több mint 2,5 gól',
        Pick.under25 => 'Kevesebb mint 2,5 gól',
        Pick.bttsYes => 'Mindkét csapat szerez gólt',
        Pick.bttsNo => 'Nem szerez mindkét csapat gólt',
      };
}

enum LegResult { pending, won, lost, voided }

enum SlipStatus { pending, won, lost, voided }

String fmtOdds(double v) => v.toStringAsFixed(2);

/// 12345.5 -> "12 345,50"
String fmtAmount(double v) {
  final neg = v < 0;
  final a = v.abs();
  final whole = a == a.roundToDouble();
  final s = whole ? a.toInt().toString() : a.toStringAsFixed(2);
  final parts = s.split('.');
  final ip = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) b.write('\u00A0');
    b.write(ip[i]);
  }
  final frac = parts.length > 1 ? ',${parts[1]}' : '';
  return '${neg ? '-' : ''}$b$frac';
}

class SlipLeg {
  final int fixtureId;
  final String home;
  final String away;
  final String league;
  final String date;
  final DateTime? kickoff;
  final Pick pick;
  final double odds;

  const SlipLeg({
    required this.fixtureId,
    required this.home,
    required this.away,
    required this.league,
    required this.date,
    required this.kickoff,
    required this.pick,
    required this.odds,
  });

  Map<String, dynamic> toJson() => {
        'fixtureId': fixtureId,
        'home': home,
        'away': away,
        'league': league,
        'date': date,
        'kickoff': kickoff?.toIso8601String(),
        'pick': pick.name,
        'odds': odds,
      };

  factory SlipLeg.fromJson(Map<String, dynamic> j) {
    final pickName = (j['pick'] ?? '').toString();
    final pick = Pick.values.firstWhere(
      (p) => p.name == pickName,
      orElse: () => Pick.home,
    );
    final k = j['kickoff'];
    return SlipLeg(
      fixtureId: (j['fixtureId'] as num?)?.toInt() ?? 0,
      home: (j['home'] ?? '').toString(),
      away: (j['away'] ?? '').toString(),
      league: (j['league'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      kickoff: k is String ? DateTime.tryParse(k) : null,
      pick: pick,
      odds: (j['odds'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class Slip {
  final int id;
  final String name;
  final double stake;
  final DateTime createdAt;
  final List<SlipLeg> legs;

  /// Ha minden tipp eldőlt, a végeredmények (LegResult indexek) itt tárolódnak,
  /// így a szelvényhez nem kell többet eredményt lekérni.
  final List<int>? settled;

  const Slip({
    required this.id,
    required this.name,
    required this.stake,
    required this.createdAt,
    required this.legs,
    this.settled,
  });

  double get totalOdds => legs.fold<double>(1.0, (p, l) => p * l.odds);

  Slip withSettled(List<int> results) => Slip(
        id: id,
        name: name,
        stake: stake,
        createdAt: createdAt,
        legs: legs,
        settled: results,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stake': stake,
        'createdAt': createdAt.toIso8601String(),
        'legs': [for (final l in legs) l.toJson()],
        'settled': settled,
      };

  factory Slip.fromJson(Map<String, dynamic> j) {
    final legs = j['legs'];
    final settled = j['settled'];
    return Slip(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] ?? '').toString(),
      stake: (j['stake'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      legs: [
        if (legs is List)
          for (final l in legs)
            if (l is Map) SlipLeg.fromJson(Map<String, dynamic>.from(l)),
      ],
      settled: settled is List
          ? [
              for (final x in settled)
                if (x is num) x.toInt(),
            ]
          : null,
    );
  }
}

/// Egy tipp kiértékelése a meccs végeredménye alapján.
LegResult evaluatePick(Pick pick, Fixture? f) {
  if (f == null) return LegResult.pending;
  if (f.status == 'Postponed' || f.status == 'Cancelled') {
    return LegResult.voided;
  }
  if (!f.isFinished || !f.hasScore) return LegResult.pending;
  final h = f.homeScore!;
  final a = f.awayScore!;
  final ok = switch (pick) {
    Pick.home => h > a,
    Pick.draw => h == a,
    Pick.away => h < a,
    Pick.over25 => h + a >= 3,
    Pick.under25 => h + a <= 2,
    Pick.bttsYes => h > 0 && a > 0,
    Pick.bttsNo => h == 0 || a == 0,
  };
  return ok ? LegResult.won : LegResult.lost;
}

class SlipEval {
  final SlipStatus status;
  final List<LegResult> legs;

  /// Az érvénytelen (elhalasztott / törölt) tippek nélküli összodds.
  final double effectiveOdds;

  const SlipEval(this.status, this.legs, this.effectiveOdds);

  double payout(double stake) => stake * effectiveOdds;
}

SlipEval evaluateSlip(Slip s, Map<int, Fixture> fixtures) {
  final List<LegResult> res;
  final snap = s.settled;
  if (snap != null && snap.length == s.legs.length) {
    res = [
      for (final i in snap)
        LegResult.values[(i < 0 || i >= LegResult.values.length) ? 0 : i],
    ];
  } else {
    res = [
      for (final l in s.legs) evaluatePick(l.pick, fixtures[l.fixtureId]),
    ];
  }

  var odds = 1.0;
  for (var i = 0; i < s.legs.length; i++) {
    if (res[i] != LegResult.voided) odds *= s.legs[i].odds;
  }

  final SlipStatus status;
  if (res.contains(LegResult.lost)) {
    status = SlipStatus.lost;
  } else if (res.contains(LegResult.pending)) {
    status = SlipStatus.pending;
  } else if (res.every((r) => r == LegResult.voided)) {
    status = SlipStatus.voided;
  } else {
    status = SlipStatus.won;
  }
  return SlipEval(status, res, odds);
}
