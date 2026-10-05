import 'package:intl/intl.dart';

String malaysiaTime(DateTime time) =>
    '${DateFormat('d MMM yyyy, h:mm a').format(time.toUtc().add(const Duration(hours: 8)))} MYT';

DateTime malaysiaDateBoundary(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).subtract(const Duration(hours: 8));

bool isMalaysiaDay(DateTime date, DateTime now) {
  final localDate = date.toUtc().add(const Duration(hours: 8));
  final localNow = now.toUtc().add(const Duration(hours: 8));
  return localDate.year == localNow.year &&
      localDate.month == localNow.month &&
      localDate.day == localNow.day;
}
