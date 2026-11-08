import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Helyi értesítések: meccskezdés előtti emlékeztető és gól-jelzés.
/// Minden hiba csendben elnyelődik, az értesítés sosem akaszthatja meg az appot.
class Alerts {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const NotificationDetails _kickoffDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'kickoff',
      'Meccskezdés',
      channelDescription: 'Emlékeztető a kedvenc csapatok meccsei előtt',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const NotificationDetails _goalDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'goals',
      'Gólok',
      channelDescription: 'Gól-jelzés a kedvenc csapatok meccsein',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (_) {}
  }

  /// Android 13+ engedélykérés. Igaz, ha az értesítések engedélyezve vannak.
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> scheduleKickoff({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.UTC),
        _kickoffDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> showGoal({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(id, title, body, _goalDetails);
    } catch (_) {}
  }
}
