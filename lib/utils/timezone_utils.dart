import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../providers/timezone_provider.dart';

DateTime? parseDateTimeValue(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  if (value is String) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  if (value is Map) {
    final rawDate = value[r'$date'];
    if (rawDate is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawDate, isUtc: true);
    }
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate.trim());
      if (parsed != null) return parsed;
    }
  }

  return null;
}

List<int>? _parseHourMinute(String? raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;

  final parts = text.split(':');
  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return [hour, minute];
}

List<int>? _parseDateOnly(String? raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  return [year, month, day];
}

List<int>? _extractDateOnlyParts(dynamic rawValue) {
  if (rawValue is String) {
    return _parseDateOnly(rawValue);
  }
  if (rawValue is Map) {
    final mapped = rawValue.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawDate = mapped[r'$date'];
    if (rawDate is String) {
      return _parseDateOnly(rawDate);
    }
  }
  return null;
}

tz.Location _resolveLocation(String? timeZoneId) {
  final normalized = TimezoneProvider.normalizeTimeZone(timeZoneId);
  try {
    return tz.getLocation(normalized);
  } catch (_) {
    // App startup initializes the timezone database, but use UTC as a safe
    // fallback for early widget construction and tests rather than throwing
    // or showing a raw ISO value to the user.
    return tz.UTC;
  }
}

tz.TZDateTime? convertToSelectedTimeZone(dynamic value, String? timeZoneId) {
  final dateOnly = _extractDateOnlyParts(value);
  if (dateOnly != null) {
    return tz.TZDateTime(
      _resolveLocation(timeZoneId),
      dateOnly[0],
      dateOnly[1],
      dateOnly[2],
    );
  }

  final parsed = parseDateTimeValue(value);
  if (parsed == null) return null;

  final baseUtc = parsed.isUtc ? parsed : parsed.toUtc();
  return tz.TZDateTime.from(baseUtc, _resolveLocation(timeZoneId));
}

tz.TZDateTime nowInTimeZone(String? timeZoneId) {
  return tz.TZDateTime.now(_resolveLocation(timeZoneId));
}

tz.TZDateTime? combineDateAndTimeForTimeZone(
  dynamic dateValue,
  String? timeValue, {
  required String? timeZoneId,
  int defaultHour = 0,
  int defaultMinute = 0,
}) {
  final dateInZone = convertToSelectedTimeZone(dateValue, timeZoneId);
  if (dateInZone == null) return null;

  final parsedTime = _parseHourMinute(timeValue);
  final hour = parsedTime != null ? parsedTime[0] : defaultHour;
  final minute = parsedTime != null ? parsedTime[1] : defaultMinute;

  return tz.TZDateTime(
    dateInZone.location,
    dateInZone.year,
    dateInZone.month,
    dateInZone.day,
    hour,
    minute,
  );
}

Duration? durationUntilForTimeZone(
  dynamic dateValue,
  String? timeValue, {
  required String? timeZoneId,
  int defaultHour = 0,
  int defaultMinute = 0,
}) {
  final target = combineDateAndTimeForTimeZone(
    dateValue,
    timeValue,
    timeZoneId: timeZoneId,
    defaultHour: defaultHour,
    defaultMinute: defaultMinute,
  );
  if (target == null) return null;
  return target.difference(nowInTimeZone(timeZoneId));
}

String formatDateTimeForTimeZone(
  dynamic value, {
  required String? timeZoneId,
  String pattern = 'MMM d, yyyy - h:mm a',
  String fallback = '-',
}) {
  final zoned = convertToSelectedTimeZone(value, timeZoneId);
  if (zoned == null) return fallback;
  return DateFormat(pattern).format(zoned);
}

String formatDateForTimeZone(
  dynamic value, {
  required String? timeZoneId,
  String pattern = 'yyyy-MM-dd',
  String fallback = '-',
}) {
  return formatDateTimeForTimeZone(
    value,
    timeZoneId: timeZoneId,
    pattern: pattern,
    fallback: fallback,
  );
}

String formatTimeForTimeZone(
  dynamic value, {
  required String? timeZoneId,
  String pattern = 'h:mm a',
  String fallback = '-',
}) {
  return formatDateTimeForTimeZone(
    value,
    timeZoneId: timeZoneId,
    pattern: pattern,
    fallback: fallback,
  );
}

String formatDateTimeForContext(
  BuildContext context,
  dynamic value, {
  String pattern = 'MMM d, yyyy - h:mm a',
  String fallback = '-',
}) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return formatDateTimeForTimeZone(
    value,
    timeZoneId: timezoneProvider.timeZoneId,
    pattern: pattern,
    fallback: fallback,
  );
}

String formatDateForContext(
  BuildContext context,
  dynamic value, {
  String pattern = 'yyyy-MM-dd',
  String fallback = '-',
}) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return formatDateForTimeZone(
    value,
    timeZoneId: timezoneProvider.timeZoneId,
    pattern: pattern,
    fallback: fallback,
  );
}

String formatTimeForContext(
  BuildContext context,
  dynamic value, {
  String pattern = 'h:mm a',
  String fallback = '-',
}) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return formatTimeForTimeZone(
    value,
    timeZoneId: timezoneProvider.timeZoneId,
    pattern: pattern,
    fallback: fallback,
  );
}

DateTime nowForContextTimeZone(BuildContext context) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return nowInTimeZone(timezoneProvider.timeZoneId);
}

tz.TZDateTime? combineDateAndTimeForContext(
  BuildContext context,
  dynamic dateValue,
  String? timeValue, {
  int defaultHour = 0,
  int defaultMinute = 0,
}) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return combineDateAndTimeForTimeZone(
    dateValue,
    timeValue,
    timeZoneId: timezoneProvider.timeZoneId,
    defaultHour: defaultHour,
    defaultMinute: defaultMinute,
  );
}

Duration? durationUntilForContext(
  BuildContext context,
  dynamic dateValue,
  String? timeValue, {
  int defaultHour = 0,
  int defaultMinute = 0,
}) {
  final timezoneProvider = context.read<TimezoneProvider>();
  return durationUntilForTimeZone(
    dateValue,
    timeValue,
    timeZoneId: timezoneProvider.timeZoneId,
    defaultHour: defaultHour,
    defaultMinute: defaultMinute,
  );
}
