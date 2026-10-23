/// Shared playback cadence across push, socket, polling and pending reminders.
class OrderAlertCadence {
  final DateTime Function() now;
  DateTime? _last;
  OrderAlertCadence({DateTime Function()? now}) : now = now ?? DateTime.now;
  bool ready(Duration interval) => _last == null || now().difference(_last!) >= interval;
  bool reserve(Duration interval) {
    if (!ready(interval)) return false;
    _last = now();
    return true;
  }
}
