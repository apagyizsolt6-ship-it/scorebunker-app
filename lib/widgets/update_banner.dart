import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';

/// Igaz, ha van újabb build, és a felhasználó még nem hessegette el a jelzést.
bool updateVisible(WidgetRef ref) {
  final info = ref.watch(updateProvider).valueOrNull;
  final dismissed = ref.watch(updateDismissedProvider);
  return info != null && info.isNewer && dismissed < info.build;
}

/// "Új verzió elérhető" sáv az app tetején.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!updateVisible(ref)) return const SizedBox.shrink();
    final info = ref.watch(updateProvider).valueOrNull!;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.system_update, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Új verzió elérhető (build ${info.build}).',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(info.apkUrl ?? info.pageUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Letöltés'),
              ),
              IconButton(
                tooltip: 'Elrejtés',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(updateDismissedProvider.notifier).state = info.build,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
