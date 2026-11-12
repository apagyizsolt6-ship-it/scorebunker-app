import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../services/update_check.dart';
import '../services/update_install.dart';

/// Igaz, ha van újabb build, és a felhasználó még nem hessegette el a jelzést.
bool updateVisible(WidgetRef ref) {
  final info = ref.watch(updateProvider).valueOrNull;
  final dismissed = ref.watch(updateDismissedProvider);
  return info != null && info.isNewer && dismissed < info.build;
}

/// "Új verzió elérhető" sáv az app tetején. A Telepítés gomb letölti az APK-t
/// az appon belül, és automatikusan megnyitja az Android telepítőt.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _busy = false;
  double? _progress;
  String? _msg;

  Future<void> _install(UpdateInfo info) async {
    final apk = info.apkUrl;
    if (apk == null) {
      await launchUrl(Uri.parse(info.pageUrl),
          mode: LaunchMode.externalApplication);
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _msg = null;
    });
    final path = await downloadApk(apk, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _busy = false;
        _progress = null;
        _msg = 'A letöltés nem sikerült. Próbáld újra, vagy tölts a Release oldalról.';
      });
      return;
    }
    final ok = await openInstaller(path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
      _msg = ok
          ? 'A telepítő megnyílt. Ha nem települ, az APK más aláírású: ilyenkor egyszer törölni kell a régi appot.'
          : 'A telepítő nem nyílt meg. Engedélyezd az APISCORES-nak az ismeretlen forrásból való telepítést.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!updateVisible(ref)) return const SizedBox.shrink();
    final info = ref.watch(updateProvider).valueOrNull!;
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;

    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.system_update, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _busy
                          ? 'Letöltés… ${((_progress ?? 0) * 100).round()}%'
                          : 'Új verzió elérhető (build ${info.build}).',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _install(info),
                    child: Text(info.apkUrl == null ? 'Megnyitás' : 'Telepítés'),
                  ),
                  IconButton(
                    tooltip: 'Elrejtés',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref
                        .read(updateDismissedProvider.notifier)
                        .state = info.build,
                  ),
                ],
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 2),
                  child: LinearProgressIndicator(value: _progress),
                ),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 2),
                  child: Text(_msg!, style: TextStyle(color: fg, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
