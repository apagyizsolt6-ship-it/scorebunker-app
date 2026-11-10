import '../services/system_bets.dart';
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

enum SlipStatus { pending, won, partial, lost, voided }

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

  /// Rendszerkötés: k a legs.length-ből. Null: sima kötés (minden tipp kell).
  final int? systemK;

  const Slip({
    required this.id,
    required this.name,
    required this.stake,
    required this.createdAt,
    required this.legs,
    this.settled,
    this.systemK,
  });

  bool get isSystem =>
      systemK != null && systemK! >= 2 && systemK! < legs.length;

  double get totalOdds => legs.fold<double>(1.0, (p, l) => p * l.odds);

  Slip withSettled(List<int> results) => Slip(
        id: id,
        name: name,
        stake: stake,
        createdAt: createdAt,
        legs: legs,
        settled: results,
        systemK: systemK,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stake': stake,
        'createdAt': createdAt.toIso8601String(),
        'legs': [for (final l in legs) l.toJson()],
        'settled': settled,
        'k': systemK,
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
      systemK: (j['k'] as num?)?.toInt(),
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

  /// Rendszerkötésnél a végső kifizetés (ha minden tipp eldőlt).
  final double? payoutAmount;

  const SlipEval(this.status, this.legs, this.effectiveOdds,
      {this.payoutAmount});

  double payout(double stake) => payoutAmount ?? stake * effectiveOdds;
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

  // Rendszerkötés: addig függő, amíg minden tipp el nem dől.
  final k = s.systemK;
  if (s.isSystem && k != null) {
    final n = s.legs.length;
    if (res.contains(LegResult.pending)) {
      return SlipEval(SlipStatus.pending, res, odds);
    }
    if (res.every((r) => r == LegResult.voided)) {
      return SlipEval(SlipStatus.voided, res, 1.0, payoutAmount: s.stake);
    }
    final winners = <double>[
      for (var i = 0; i < n; i++)
        if (res[i] == LegResult.won)
          s.legs[i].odds
        else if (res[i] == LegResult.voided)
          1.0,
    ];
    final payout = systemPayout(winners, n, k, s.stake);
    final st = payout <= 0
        ? SlipStatus.lost
        : (payout >= s.stake ? SlipStatus.won : SlipStatus.partial);
    return SlipEval(st, res, payout / s.stake, payoutAmount: payout);
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
