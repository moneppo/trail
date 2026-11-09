import 'package:flutter/material.dart';

import '../theme/settings_controller.dart';

const _metersPerMile = 1609.344;
const _feetPerMeter = 3.28084;

/// A walk's length: "3.20 km" or "1.99 mi".
String formatDistance(double meters, DistanceUnit units) =>
    units == DistanceUnit.km
    ? '${(meters / 1000).toStringAsFixed(2)} km'
    : '${(meters / _metersPerMile).toStringAsFixed(2)} mi';

/// A short length such as a marked stretch: "140 m" or "460 ft".
String formatShortDistance(double meters, DistanceUnit units) =>
    units == DistanceUnit.km
    ? '${meters.round()} m'
    : '${(meters * _feetPerMeter).round()} ft';

String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
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

/// A date and time the way a person would say it: "Today, 6:42 PM",
/// "Yesterday, 6:42 PM", "Tuesday, 6:42 PM" within the last week, then
/// "Oct 24, 2:10 PM", adding the year for older walks. The time follows the
/// device's 12 or 24 hour setting.
String friendlyDateTime(BuildContext context, DateTime when) {
  final local = when.toLocal();
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo == 0) return 'Today, $time';
  if (daysAgo == 1) return 'Yesterday, $time';
  if (daysAgo > 1 && daysAgo < 7) {
    return '${_weekdays[local.weekday - 1]}, $time';
  }
  final date = '${_months[local.month - 1]} ${local.day}';
  return local.year == now.year
      ? '$date, $time'
      : '$date, ${local.year}, $time';
}
