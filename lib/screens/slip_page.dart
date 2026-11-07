import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_catalog.dart';
import '../models/fixture.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Egyelőre az eredeti kiválasztó. A következő lépésben valódi szelvény lesz
/// (tippek, odds, összodds, mentés).
class SlipWizardPage extends ConsumerStatefulWidget {
  const SlipWizardPage({super.key});

  @override
  ConsumerState<SlipWizardPage> createState() => _SlipWizardPageState();
}

class _SlipWizardPageState extends ConsumerState<SlipWizardPage> {
  final Set<int> selected = {};

  @override
  Widget build(BuildContext context) {
    final fixtures = ref.watch(liveFixturesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Szelvényvarázsló'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Válaszd ki a mérkőzéseket, és a varázsló összeállítja a szelvényt',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: fixtures.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(fixturesProvider),
              ),
              data: (list) {
                final open = list.where((m) => m.isScheduled).toList()
                  ..sort(byKickoff);
                if (open.isEmpty) {
                  return const Center(
                      child: Text('Nincs kiválasztható meccs ezen a napon.'));
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: open.map((m) {
                    final isSelected = selected.contains(m.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3)
                          : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selected.add(m.id);
                            } else {
                              selected.remove(m.id);
                            }
                          });
                        },
                        title: Text('${m.homeTeam} - ${m.awayTeam}'),
                        subtitle:
                            Text('${leagueHu(m.leagueName)} • ${m.timeLabel}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Szelvény összeállítva'),
                              content: Text(
                                  '${selected.length} esemény kiválasztva.\n\n(Később ide jön az odds és a kombináció)'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                  child: Text('Szelvény készítése (${selected.length})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
