import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_adjust.dart';
import '../providers.dart';

/// Kézi korrekció beállítása egy csapatra (hiányzó játékos, forma, ...).
Future<void> showAdjustSheet(BuildContext context, int teamId, String name) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AdjustSheet(teamId: teamId, name: name),
  );
}

class _AdjustSheet extends ConsumerStatefulWidget {
  final int teamId;
  final String name;
  const _AdjustSheet({required this.teamId, required this.name});

  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends ConsumerState<_AdjustSheet> {
  int _atk = 0;
  int _def = 0;
  int _days = 14;
  late final TextEditingController _note;
  bool _existing = false;

  static const List<(String, int, int)> _presets = [
    ('Kulcsjátékos hiányzik', -10, 5),
    ('Védő vagy kapus hiányzik', 0, 12),
    ('Tartalékos kezdő', -12, 8),
    ('Rossz forma', -8, 5),
    ('Jó forma / motivált', 8, -4),
  ];

  @override
  void initState() {
    super.initState();
    final cur = ref.read(teamAdjustProvider)[widget.teamId];
    _existing = cur != null;
    _atk = cur?.attackPct ?? 0;
    _def = cur?.defencePct ?? 0;
    _note = TextEditingController(text: cur?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final until = DateTime.now().add(Duration(days: _days)).millisecondsSinceEpoch;
    ref.read(teamAdjustProvider.notifier).set(
          widget.teamId,
          TeamAdjust(
            attackPct: _atk,
            defencePct: _def,
            note: _note.text.trim(),
            untilMs: until,
          ),
        );
    Navigator.pop(context);
  }

  String _sign(int v) => v > 0 ? '+$v%' : '$v%';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Korrekció – ${widget.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'A modell nem látja a sérüléseket és a kispadot. Itt kézzel módosíthatod, '
              'mennyi gólt várunk a csapattól, és mennyit kaphat.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ActionChip(
                    label: Text(p.$1),
                    onPressed: () => setState(() {
                      _atk = p.$2;
                      _def = p.$3;
                      if (_note.text.isEmpty) _note.text = p.$1;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Támadás (lőtt gólok): ${_sign(_atk)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _atk.toDouble(),
              min: -30,
              max: 30,
              divisions: 60,
              label: _sign(_atk),
              onChanged: (v) => setState(() => _atk = v.round()),
            ),
            Text('Védekezés (kapott gólok): ${_sign(_def)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              'Pozitív érték: a csapat több gólt kap, negatív: kevesebbet.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            Slider(
              value: _def.toDouble(),
              min: -30,
              max: 30,
              divisions: 60,
              label: _sign(_def),
              onChanged: (v) => setState(() => _def = v.round()),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Megjegyzés (nem kötelező)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Érvényes: '),
                const SizedBox(width: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 nap')),
                    ButtonSegment(value: 14, label: Text('14 nap')),
                    ButtonSegment(value: 30, label: Text('30 nap')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A korrekció a meccs részleteiben, a szelvényen és az összehasonlításban '
              'számít. A Trendek, a Legjobb esélyek és a visszamérés az alapmodellt használják, '
              'hogy a kalibráció ne torzuljon.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (_existing)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(teamAdjustProvider.notifier).clear(widget.teamId);
                        Navigator.pop(context);
                      },
                      child: const Text('Törlés'),
                    ),
                  ),
                if (_existing) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Mentés'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
