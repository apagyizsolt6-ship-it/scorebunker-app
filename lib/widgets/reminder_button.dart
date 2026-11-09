import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../models/reminder.dart';
import '../providers.dart';

/// Csengő-gomb: emlékeztetőt kér egyetlen meccs kezdése előtt.
/// Csak le nem játszott meccsnél jelenik meg.
class ReminderButton extends ConsumerWidget {
  final Fixture fixture;
  const ReminderButton({super.key, required this.fixture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!fixture.isScheduled) return const SizedBox.shrink();
    final on = ref.watch(remindersProvider).containsKey(fixture.id);
    final minutes = ref.watch(settingsProvider.select((s) => s.kickoffMinutes));
    return IconButton(
      tooltip: on ? 'Emlékeztető törlése' : 'Emlékeztető kérése',
      icon: Icon(
        on ? Icons.notifications_active : Icons.notifications_none,
        color: on ? Colors.amber : null,
      ),
      onPressed: () async {
        final r = await ref.read(remindersProvider.notifier).toggle(fixture);
        if (!context.mounted) return;
        final msg = switch (r) {
          ReminderResult.added => 'Emlékeztető beállítva: $minutes perccel a kezdés előtt.',
          ReminderResult.removed => 'Emlékeztető törölve.',
          ReminderResult.tooLate => 'Ez a meccs túl közel van, vagy már elkezdődött.',
          ReminderResult.noTime => 'Ehhez a meccshez nincs pontos kezdési idő.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }
}
