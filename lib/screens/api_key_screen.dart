import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/sport_api.dart';

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final k = _controller.text.trim();
    if (k.isEmpty) {
      setState(() => _error = 'Írd be az API-kulcsot.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Próbahívás: csak érvényes kulcsot mentünk el.
      await SportApi(k).fixturesByDate(DateTime.now());
      await ref.read(apiKeyProvider.notifier).setKey(k);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    await ref.read(apiKeyProvider.notifier).clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = (ref.watch(apiKeyProvider).valueOrNull ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('API-kulcs'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Add meg a sportapi.ai kulcsodat (sk_live_...). '
            'A kulcs csak a készüléken tárolódik.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _hide,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: hasKey ? 'Új API-kulcs' : 'API-kulcs',
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ellenőrzés és mentés'),
          ),
          if (hasKey) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Kulcs törlése'),
            ),
          ],
        ],
      ),
    );
  }
}
