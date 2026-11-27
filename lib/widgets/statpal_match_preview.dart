import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../providers.dart';

class StatPalMatchPreview extends ConsumerStatefulWidget {
  final Fixture fixture;
  const StatPalMatchPreview({super.key, required this.fixture});

  @override
  ConsumerState<StatPalMatchPreview> createState() => _StatPalMatchPreviewState();
}

class _StatPalMatchPreviewState extends ConsumerState<StatPalMatchPreview> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant StatPalMatchPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixture.id != widget.fixture.id) _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = ref.read(apiProvider);
    if (api == null) return const {};
    final results = await Future.wait<Map<String, dynamic>>([
      _safe(() => api.predictions(widget.fixture.id)),
      _safe(() => api.weatherForecast(widget.fixture.id)),
    ]);
    return {'prediction': results[0], 'weather': results[1]};
  }

  Future<Map<String, dynamic>> _safe(
      Future<Map<String, dynamic>> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return const {};
    }
  }

  String _label(String key) {
    final normalized = key
        .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    const translations = <String, String>{
      'prediction': 'Előrejelzés',
      'predicted outcome': 'Várható kimenetel',
      'home win': 'Hazai győzelem',
      'draw': 'Döntetlen',
      'away win': 'Vendég győzelem',
      'home probability': 'Hazai esély',
      'draw probability': 'Döntetlen esély',
      'away probability': 'Vendég esély',
      'temperature': 'Hőmérséklet',
      'feels like': 'Hőérzet',
      'description': 'Időjárás',
      'condition': 'Időjárás',
      'wind speed': 'Szélsebesség',
      'wind direction': 'Szélirány',
      'humidity': 'Páratartalom',
      'rain': 'Csapadék',
      'chance of rain': 'Eső esélye',
      'venue': 'Helyszín',
      'city': 'Város',
    };
    return translations[normalized.toLowerCase()] ??
        (normalized.isEmpty ? key : '${normalized[0].toUpperCase()}${normalized.substring(1)}');
  }

  List<(String, String)> _flatten(dynamic value, [String prefix = '', int depth = 0]) {
    final out = <(String, String)>[];
    if (depth > 3 || value == null) return out;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (key.toLowerCase() == 'id' || key.toLowerCase().contains('access_key')) continue;
        final label = prefix.isEmpty ? key : '$prefix • $key';
        out.addAll(_flatten(entry.value, label, depth + 1));
        if (out.length >= 12) break;
      }
    } else if (value is List) {
      for (var i = 0; i < value.length && i < 4; i++) {
        out.addAll(_flatten(value[i], prefix.isEmpty ? '${i + 1}.' : '$prefix ${i + 1}.', depth + 1));
        if (out.length >= 12) break;
      }
    } else if (value is String || value is num || value is bool) {
      final text = value.toString().trim();
      if (text.isNotEmpty && prefix.isNotEmpty) out.add((prefix, text));
    }
    return out;
  }

  Widget _dataCard(String title, IconData icon, dynamic raw) {
    dynamic data = raw;
    if (raw is Map && raw['data'] != null) data = raw['data'];
    final rows = _flatten(data).take(8).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(_label(row.$1), style: const TextStyle(fontSize: 12))),
                        const SizedBox(width: 10),
                        Flexible(child: Text(row.$2, textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final prediction = _dataCard('StatPal előrejelzés', Icons.auto_graph, data['prediction']);
        final weather = _dataCard('Mérkőzésnapi időjárás', Icons.cloud_outlined, data['weather']);
        if (prediction is SizedBox && weather is SizedBox) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              child: Text('Mérkőzés-előnézet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            prediction,
            weather,
          ],
        );
      },
    );
  }
}
