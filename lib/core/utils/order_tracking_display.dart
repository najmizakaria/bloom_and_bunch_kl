import 'package:intl/intl.dart';

String trackingOrderNumber(String number) => number.replaceFirstMapped(
  RegExp(r'^#ORDER(\d+)$'),
  (match) => '#${match[1]}',
);

String trackingDate(Object value) {
  final raw = value.toString();
  final date = DateTime.tryParse(raw);
  return date == null
      ? raw
      : DateFormat('EEE, d MMM yyyy', 'en_US').format(date);
}

String trackingAddress(String address, {bool keepMapCodeOnly = true}) {
  final parts = address
      .split(RegExp(r'[,\n]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  final plusCode = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,7}$',
    caseSensitive: false,
  );
  final postcodeWithCity = RegExp(r'^(\d{5}) (.+)$');
  final readable = parts.where((part) => !plusCode.hasMatch(part)).toList();
  final seen = <String>{};
  return (readable.isEmpty && keepMapCodeOnly ? parts : readable)
      .where((part) {
        final key = part.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (!seen.add(key)) return false;
        final combined = postcodeWithCity.firstMatch(key);
        if (combined == null) return true;
        if (seen.contains(combined[1]) && seen.contains(combined[2])) {
          return false;
        }
        seen.addAll([combined[1]!, combined[2]!]);
        return true;
      })
      .join(', ');
}
