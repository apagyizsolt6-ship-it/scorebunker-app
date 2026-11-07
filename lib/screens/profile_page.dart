import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/live_score.dart';
import '../providers.dart';
import '../services/sport_api.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _mask(String? k) {
    if (k == null || k.isEmpty) return 'Nincs megadva';
    if (k.length <= 12) return '••••••••';
    return '${k.substring(0, 8)}…${k.substring(k.length - 4)}';
  }

  /// 1234 -> "1 234"
  String _n(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('\u00A0');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _quotaRow(
    BuildContext context,
    String label,
    int? limit,
    int? remaining,
    DateTime? reset,
  ) {
    if (limit == null || remaining == null || limit <= 0) {
      return const SizedBox.shrink();
    }
    final value = (remaining / limit).clamp(0.0, 1.0).toDouble();
    final scheme = Theme.of(context).colorScheme;
    final low = value < 0.1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${_n(remaining)} / ${_n(limit)} kérés maradt',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: low ? Colors.red : scheme.primary,
            ),
          ),
          if (reset != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Újraindul: ${DateFormat('MM.dd. HH:mm').format(reset)}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quotaCard(BuildContext context, ApiQuota? q) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed_outlined, size: 20),
                SizedBox(width: 8),
                Text('API-keret',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            if (q == null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Az első adatlekérés után jelenik meg.',
                  style: TextStyle(fontSize: 13),
                ),
              )
            else ...[
              _quotaRow(context, 'Ma', q.dayLimit, q.dayRemaining, q.dayReset),
              _quotaRow(context, 'E hónapban', q.monthLimit, q.monthRemaining,
                  q.monthReset),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(apiKeyProvider).valueOrNull;
    final quota = ref.watch(quotaProvider);
    final settings = ref.watch(settingsProvider);
    final favCount = ref.watch(favoritesProvider).length;
    final conn = ref.watch(liveProvider.select((s) => s.conn));

    final liveText = switch (conn) {
      LiveConn.on => 'Kapcsolódva',
      LiveConn.connecting => 'Kapcsolódás…',
      LiveConn.off => 'Nincs kapcsolat – koppints az újrapróbáláshoz',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.workspace_premium),
            title: Text('Scorebunker PRO'),
            subtitle: Text('Hamarosan elérhető'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('API-kulcs'),
            subtitle: Text(_mask(key)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openApiKeyScreen(context),
          ),
          const SizedBox(height: 8),
          _quotaCard(context, quota),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Kedvenc csapatok'),
            subtitle: Text(favCount == 0 ? 'Még nincs' : '$favCount csapat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Élő frissítés'),
            subtitle: Text(liveText),
            onTap: () => ref.read(liveProvider.notifier).ensureConnected(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Megjelenés',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, label: Text('Világos')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sötét')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) =>
                  ref.read(settingsProvider.notifier).setThemeMode(s.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.shield_outlined),
            title: const Text('Csapatlogók'),
            subtitle: const Text(
              'Minden új logó betöltése API-kérésnek számíthat a keretedből. '
              'A letöltött logók eltárolódnak.',
            ),
            value: settings.showLogos,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setShowLogos(v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Névjegy'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Scorebunker',
              applicationVersion: '1.1.0',
              children: const [
                SizedBox(height: 8),
                Text(
                  'Adatforrás: SportAPI (sportapi.ai). Az élő állások '
                  'WebSocketen érkeznek, a tabellák és statisztikák REST API-n.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
