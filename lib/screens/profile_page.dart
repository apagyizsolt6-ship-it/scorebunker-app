import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/live_score.dart';
import '../providers.dart';
import '../services/alerts.dart';
import '../services/sport_api.dart';
import '../services/update_check.dart';
import '../widgets/common.dart';
import 'backtest_screen.dart';
import 'backup_screen.dart';
import 'fav_calendar_screen.dart';
import 'favorites_screen.dart';
import 'leagues_screen.dart';

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
    final elo = ref.watch(eloProvider);

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
            title: Text('APISCORES PRO'),
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
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Kedvencek heti naptára'),
            subtitle: const Text('A következő 7 nap meccsei, emlékeztetővel'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavCalendarScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Bajnokság-szűrő'),
            subtitle: Text(
              'Kiemelt: ${ref.watch(leaguePrefsProvider).pinned.length} • '
              'Rejtett: ${ref.watch(leaguePrefsProvider).hidden.length}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaguesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Élő frissítés'),
            subtitle: Text(liveText),
            onTap: () => ref.read(liveProvider.notifier).ensureConnected(),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Trendek visszamérése'),
            subtitle: const Text('Hány trend és becslés jött be a lejátszott meccseken'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BacktestScreen()),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Értesítések',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Kezdés-értesítés a kedvenceknek'),
            subtitle: Text(settings.notifyKickoff
                ? '${settings.kickoffMinutes} perccel a kezdés előtt'
                : 'Kikapcsolva'),
            value: settings.notifyKickoff,
            onChanged: (v) async {
              if (v) {
                final ok = await Alerts.requestPermission();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Az értesítések nincsenek engedélyezve a telefon beállításaiban.'),
                    ),
                  );
                }
              }
              ref.read(settingsProvider.notifier).setNotifyKickoff(v);
            },
          ),
          if (settings.notifyKickoff)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 15, label: Text('15 perc')),
                  ButtonSegment(value: 30, label: Text('30 perc')),
                  ButtonSegment(value: 60, label: Text('60 perc')),
                ],
                selected: {settings.kickoffMinutes},
                onSelectionChanged: (s) => ref
                    .read(settingsProvider.notifier)
                    .setKickoffMinutes(s.first),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.sports_score_outlined),
            title: const Text('Gól-értesítés'),
            subtitle: const Text(
                'A kedvenc csapatok meccsein, amíg az app meg van nyitva'),
            value: settings.notifyGoals,
            onChanged: (v) async {
              if (v) await Alerts.requestPermission();
              ref.read(settingsProvider.notifier).setNotifyGoals(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.flag_outlined),
            title: const Text('Félidő és végeredmény'),
            subtitle: const Text('A kedvenc csapatok meccsein, megnyitott appnál'),
            value: settings.notifyStatus,
            onChanged: (v) async {
              if (v) await Alerts.requestPermission();
              ref.read(settingsProvider.notifier).setNotifyStatus(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.square_rounded, color: Colors.red),
            title: const Text('Piros lap'),
            subtitle: const Text(
                'A kedvenc csapatok élő meccsein (3 percenként ellenőrzi)'),
            value: settings.notifyRed,
            onChanged: (v) async {
              if (v) await Alerts.requestPermission();
              ref.read(settingsProvider.notifier).setNotifyRed(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined),
            title: const Text('Csendes órák'),
            subtitle: Text(settings.quietEnabled
                ? '${settings.quietStart.toString().padLeft(2, '0')}:00 – '
                    '${settings.quietEnd.toString().padLeft(2, '0')}:00 között nem jön értesítés'
                : 'Kikapcsolva'),
            value: settings.quietEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setQuietEnabled(v),
          ),
          if (settings.quietEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Tól'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: settings.quietStart,
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setQuietHours(v, settings.quietEnd);
                      }
                    },
                  ),
                  const Spacer(),
                  const Text('Ig'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: settings.quietEnd,
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setQuietHours(settings.quietStart, v);
                      }
                    },
                  ),
                ],
              ),
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
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Csapaterő (Elo)'),
            subtitle: Text(elo.isEmpty
                ? 'Még nincs adat – az első indítás után épül a lejátszott meccsekből'
                : '${elo.ratings.length} csapat • frissítve: ${elo.lastDate}'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Verzió'),
            subtitle: Text(kBuildNumber > 0
                ? 'Build $kBuildNumber'
                : 'Helyi (fejlesztői) build'),
            trailing: TextButton(
              onPressed: () async {
                ref.read(updateDismissedProvider.notifier).state = 0;
                ref.invalidate(updateProvider);
                final info = await ref.read(updateProvider.future);
                if (!context.mounted) return;
                final msg = info == null
                    ? 'Nem sikerült ellenőrizni, vagy nincs elérhető Release.'
                    : (info.isNewer
                        ? 'Új verzió elérhető: build ${info.build}.'
                        : 'A legújabb verziót használod.');
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(msg)));
              },
              child: const Text('Frissítés keresése'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Mentés és visszaállítás'),
            subtitle: const Text('Kedvencek, szelvények, beállítások'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Névjegy'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'APISCORES',
              applicationVersion: '1.8.0',
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
