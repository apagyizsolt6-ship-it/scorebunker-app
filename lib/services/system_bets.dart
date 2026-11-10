/// Rendszerkötés (k a n-ből) számítások.

/// n alatt k: a kombinációk száma.
int binomial(int n, int k) {
  if (k < 0 || k > n) return 0;
  var kk = k;
  if (kk > n - kk) kk = n - kk;
  var r = 1;
  for (var i = 1; i <= kk; i++) {
    r = r * (n - kk + i) ~/ i;
  }
  return r;
}

/// A k elemű részhalmazok szorzatainak összege (k-adik elemi szimmetrikus
/// polinom) – ez adja a rendszer összes nyertes kombinációjának odds-összegét.
double elementarySymmetric(List<double> v, int k) {
  if (k <= 0) return 1;
  if (k > v.length) return 0;
  final dp = List<double>.filled(k + 1, 0);
  dp[0] = 1;
  for (var i = 0; i < v.length; i++) {
    final top = (i + 1) < k ? (i + 1) : k;
    for (var j = top; j >= 1; j--) {
      dp[j] += dp[j - 1] * v[i];
    }
  }
  return dp[k];
}

/// Kifizetés, ha a `winners` odds-ú tippek jönnek be (a többi veszít).
/// A tét egyenlően oszlik el a C(n, k) kombináció között.
double systemPayout(List<double> winners, int n, int k, double stake) {
  final combos = binomial(n, k);
  if (combos == 0) return 0;
  return stake / combos * elementarySymmetric(winners, k);
}

class SystemOutcome {
  final int hits;
  final double minPayout;
  final double maxPayout;
  const SystemOutcome(this.hits, this.minPayout, this.maxPayout);
}

/// Találatszámonként a legrosszabb és a legjobb eset (attól függően, hogy
/// a legkisebb vagy a legnagyobb odds-ú tippek jönnek be).
List<SystemOutcome> systemOutcomes(List<double> odds, int k, double stake) {
  final n = odds.length;
  final sorted = [...odds]..sort();
  final out = <SystemOutcome>[];
  for (var j = k; j <= n; j++) {
    final low = sorted.sublist(0, j);
    final high = sorted.sublist(n - j);
    out.add(SystemOutcome(
      j,
      systemPayout(low, n, k, stake),
      systemPayout(high, n, k, stake),
    ));
  }
  return out;
}
