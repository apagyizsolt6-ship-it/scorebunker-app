/// Egy meccsre kért emlékeztető.
class Reminder {
  final int fixtureId;
  final String title;
  final String body;
  final int atMs; // az értesítés időpontja (epoch ms)

  const Reminder({
    required this.fixtureId,
    required this.title,
    required this.body,
    required this.atMs,
  });

  Map<String, dynamic> toJson() => {
        'f': fixtureId,
        't': title,
        'b': body,
        'a': atMs,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        fixtureId: (j['f'] as num?)?.toInt() ?? 0,
        title: (j['t'] ?? '').toString(),
        body: (j['b'] ?? '').toString(),
        atMs: (j['a'] as num?)?.toInt() ?? 0,
      );
}

enum ReminderResult { added, removed, tooLate, noTime }
