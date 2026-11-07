import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../providers.dart';
import '../screens/api_key_screen.dart';
import '../services/sport_api.dart';

void openApiKeyScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
  );
}

class NoKeyView extends StatelessWidget {
  const NoKeyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Az adatok megjelenítéséhez add meg a SportAPI kulcsodat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => openApiKeyScreen(context),
              child: const Text('API-kulcs megadása'),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isAuth = error is ApiException && (error as ApiException).status == 401;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(errorText(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (isAuth)
              FilledButton(
                onPressed: () => openApiKeyScreen(context),
                child: const Text('API-kulcs módosítása'),
              )
            else
              FilledButton(onPressed: onRetry, child: const Text('Újra')),
          ],
        ),
      ),
    );
  }
}

/// Csapatlogó a SportAPI-ról (a Profilban kapcsolható). Kikapcsolva nem
/// foglal helyet és nem indít kérést. A letöltött logók tárolódnak.
class TeamLogo extends ConsumerWidget {
  final int teamId;
  final double size;
  final bool padRight;

  const TeamLogo({
    super.key,
    required this.teamId,
    this.size = 22,
    this.padRight = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(settingsProvider.select((s) => s.showLogos));
    final key = ref.watch(apiKeyProvider).valueOrNull;
    if (!show || key == null || key.isEmpty || teamId == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 8 : 0),
      child: CachedNetworkImage(
        imageUrl: 'https://sportapi.ai/api/teams/$teamId/logo',
        httpHeaders: {'X-Api-Key': key},
        cacheKey: 'sportapi_logo_$teamId',
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(width: size, height: size),
        errorWidget: (_, __, ___) =>
            Icon(Icons.shield_outlined, size: size * 0.9),
      ),
    );
  }
}

/// Hosszú nyomásra: a meccs két csapatának kedvencekhez adása / törlése.
Future<void> showTeamFavSheet(BuildContext context, Fixture f) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final favs = ref.watch(favoritesProvider);
        Widget tile(int id, String name) {
          final on = favs.containsKey(id);
          return ListTile(
            leading: Icon(
              on ? Icons.star : Icons.star_border,
              color: on ? Colors.amber : null,
            ),
            title: Text(name),
            subtitle: Text(on
                ? 'Kedvenc – koppints az eltávolításhoz'
                : 'Hozzáadás a kedvencekhez'),
            onTap: () =>
                ref.read(favoritesProvider.notifier).toggle(id, name),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(f.homeId, f.homeTeam),
              tile(f.awayId, f.awayTeam),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
