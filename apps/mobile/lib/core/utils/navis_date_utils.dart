import 'package:intl/intl.dart';

class NavisDateUtils {
  NavisDateUtils._();

  static int daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy HH:mm').format(date.toLocal());
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  static String formatRelative(DateTime date) {
    final days = daysUntil(date);
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days > 0 && days < 7) return 'In $days days';
    if (days < 0 && days > -7) return '${-days} days ago';
    return formatDate(date);
  }

  static bool isExpired(DateTime date) {
    return daysUntil(date) < 0;
  }

  static bool isCritical(DateTime date, {int criticalDays = 7}) {
    final days = daysUntil(date);
    return days >= 0 && days <= criticalDays;
  }

  static bool isWarning(DateTime date,
      {int warningDays = 30, int criticalDays = 7}) {
    final days = daysUntil(date);
    return days > criticalDays && days <= warningDays;
  }

  static bool isOk(DateTime date, {int warningDays = 30}) {
    return daysUntil(date) > warningDays;
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Zero-padded HH:MM:SS elapsed clock (e.g. trip recording HUD).
  static String formatHms(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
