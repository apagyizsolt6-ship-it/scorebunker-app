import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final entries = favs.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Kedvenc csapatok'), centerTitle: true),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Még nincs kedvenc csapatod.\n\n'
                  'A Meccsek fülön nyomd hosszan egy meccskártyát, '
                  'vagy koppints a csillagra a meccs részletei között.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(e.value),
                  trailing: IconButton(
                    tooltip: 'Eltávolítás',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).remove(e.key),
                  ),
                );
              },
            ),
    );
  }
}
