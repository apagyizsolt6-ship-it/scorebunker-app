import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/common.dart';
import 'team_screen.dart';

/// Szezon-előrejelzés: becsült végső pontszám és esély a bajnoki címre,
/// a legjobb 4-be kerülésre és a kiesésre (Monte Carlo szimulációval).
class ProjectionTab extends ConsumerWidget {
  final int leagueId;
  const ProjectionTab({super.key, required this.leagueId});

  String _pct(double p) {
    if (p < 0.005) return '–';
    if (p < 0.01) return '<1%';
    return '${(p * 100).round()}%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(projectionProvider(leagueId));
    final scheme = Theme.of(context).colorScheme;

    return data.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Szezon szimulálása…'),
            ],
          ),
        ),
      ),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(projectionProvider(leagueId)),
      ),
      data: (p) {
        if (p == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ehhez a bajnoksághoz nem számolható előrejelzés '
                '(csoportos, konferenciás vagy már lezárult szezon).',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final head = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        );
        Widget cell(String t, double w, {bool bold = false, Color? color}) =>
            SizedBox(
              width: w,
              child: Text(
                t,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                ),
              ),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                '${p.sims} szimuláció • átlagosan ${p.remaining.toStringAsFixed(0)} meccs van még hátra csapatonként',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text('Csapat', style: head)),
                  SizedBox(
                      width: 48,
                      child: Text('Várt P',
                          textAlign: TextAlign.center, style: head)),
                  SizedBox(
                      width: 46,
                      child: Text('Bajnok',
                          textAlign: TextAlign.center, style: head)),
                  SizedBox(
                      width: 42,
                      child: Text('Top 4',
                          textAlign: TextAlign.center, style: head)),
                  SizedBox(
                      width: 44,
                      child: Text('Kiesés',
                          textAlign: TextAlign.center, style: head)),
                ],
              ),
            ),
            for (final r in p.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamScreen(
                            teamId: r.team.teamId, name: r.team.name),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${r.team.position}. ${r.team.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          cell(r.expectedPoints.toStringAsFixed(0), 48,
                              bold: true),
                          cell(_pct(r.pTitle), 46,
                              bold: r.pTitle >= 0.2,
                              color: r.pTitle >= 0.2 ? Colors.green : null),
                          cell(_pct(r.pTop4), 42),
                          cell(_pct(r.pBottom), 44,
                              bold: r.pBottom >= 0.2,
                              color: r.pBottom >= 0.2 ? Colors.red : null),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Durva becslés. Kétkörös lebonyolítást feltételez, a hátralévő '
              'meccsek ellenfelei és a pályaválasztás véletlenszerűek, a '
              'csapaterő a szezon eddigi gólarányaiból jön. Nem számol '
              'sérülésekkel, a fordulók valós sorsolásával és a bajnokság '
              'saját kieső/kupahelyeivel (kiesés: az utolsó '
              '${p.bottomZone} hely). Nem garancia és nem ajánlás.',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
