import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/backup.dart';

/// Mentés és visszaállítás: az adatok egyetlen szövegbe másolhatók
/// (pl. jegyzetbe vagy üzenetbe), és onnan visszatölthetők.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _includeKey = false;
  final TextEditingController _text = TextEditingController();
  String? _status;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final json = await BackupService.export(includeApiKey: _includeKey);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() => _status =
        'A mentés (${json.length} karakter) a vágólapra került. Illeszd be egy '
        'jegyzetbe vagy üzenetbe, és őrizd meg.');
  }

  Future<void> _pasteFromClipboard() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final t = d?.text ?? '';
    if (t.trim().isEmpty) {
      setState(() => _status = 'A vágólap üres.');
      return;
    }
    _text.text = t;
    setState(() => _status = null);
  }

  Future<void> _restore() async {
    final text = _text.text;
    final sum = BackupService.peek(text);
    if (sum == null) {
      setState(() => _status = 'A beillesztett szöveg nem APISCORES-mentés.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Visszaállítás?'),
        content: Text(
          'Mentés ideje: ${sum.created.isEmpty ? 'ismeretlen' : sum.created.split('T').first}\n'
          'Kedvenc csapatok: ${sum.favorites}\n'
          'Mentett szelvények: ${sum.slips}\n'
          'API-kulcs: ${sum.hasApiKey ? 'benne van' : 'nincs benne'}\n\n'
          'A jelenlegi kedvencek, szelvények és beállítások felülíródnak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Visszaállítás'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await BackupService.restore(text);
    if (!mounted) return;
    if (!done) {
      setState(() => _status = 'A visszaállítás nem sikerült.');
      return;
    }
    ref.invalidate(favoritesProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(slipsProvider);
    ref.invalidate(leaguePrefsProvider);
    ref.invalidate(calibrationProvider);
    ref.invalidate(apiKeyProvider);
    _text.clear();
    setState(() => _status = 'Kész, az adatok visszaálltak.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mentés és visszaállítás'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mentés',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'Kedvencek, mentett szelvények, beállítások, bajnokság-szűrő, '
                    'visszamérési napló. Az emlékeztetők nem kerülnek bele.',
                    style: TextStyle(fontSize: 12),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('API-kulcs is'),
                    subtitle: const Text(
                      'Figyelem: a mentés ilyenkor tartalmazza a titkos kulcsot.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _includeKey,
                    onChanged: (v) => setState(() => _includeKey = v),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Másolás a vágólapra'),
                    onPressed: _export,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Visszaállítás',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'Másold ki a korábbi mentést, és illeszd be ide.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Ide kerül a mentés szövege',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.paste),
                          label: const Text('Beillesztés'),
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.restore),
                          label: const Text('Visszaállítás'),
                          onPressed: _restore,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _status!,
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
