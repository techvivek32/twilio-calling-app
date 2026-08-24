/// Formatting helpers shared by every screen.
library;

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Renders an E.164 number the way the mockups do: +1 (555) 012-3456.
String formatPhoneNumber(String value) {
  final digits = digitsOnly(value);

  if (digits.length == 11 && digits.startsWith('1')) {
    return '+1 (${digits.substring(1, 4)}) '
        '${digits.substring(4, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '+1 (${digits.substring(0, 3)}) '
        '${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  return value;
}

/// Normalises typed input to E.164 before sending it to the server.
/// Cleans an already-international number without inventing a country code.
///
/// Assuming `+1` for any 10-digit input silently turned foreign numbers into
/// invalid US ones, which Twilio rejected. National numbers are combined with
/// an explicit country by `toE164` in `core/countries.dart` instead.
String normaliseE164(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  final digits = digitsOnly(trimmed);
  if (digits.isEmpty) return '';
  return '+$digits';
}

/// `4m 12s`, matching the call-history and call-ended screens.
String formatDuration(int seconds) {
  if (seconds <= 0) return '0s';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return minutes > 0 ? '${minutes}m ${rest}s' : '${rest}s';
}

/// `02:45` for the live call timer.
String formatClock(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// Relative-ish stamp used across lists: time today, weekday this week, date otherwise.
String formatTimestamp(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(local.year, local.month, local.day);
  final difference = today.difference(that).inDays;

  if (difference == 0) return _clockLabel(local);
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return _weekdays[local.weekday - 1];
  return '${_months[local.month - 1]} ${local.day}';
}

/// Full stamp for detail screens: `Oct 24, 2023 - 09:41 AM`.
String formatFullTimestamp(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year} - '
      '${_clockLabel(local)}';
}

String _clockLabel(DateTime value) {
  final hour24 = value.hour;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
}

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
