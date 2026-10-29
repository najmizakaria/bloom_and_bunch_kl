import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/commerce_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/cart_item_model.dart';

Future<String?> chooseDeliveryDate(
  BuildContext context,
  List<CartItemModel> items,
) async {
  try {
    final allDates = await Future.wait(
      items.where((i) => i.type != 'addon').map(CommerceService.dates),
    );
    if (!context.mounted) return null;
    final available =
        allDates.isEmpty
              ? <String>[]
              : allDates.first
                    .where(
                      (day) => allDates.every((days) => days.contains(day)),
                    )
                    .toList()
          ..sort();
    if (available.isEmpty) {
      throw StateError(
        'No delivery dates are available. Please contact the store.',
      );
    }
    final allowed = available.toSet();
    final current = items.first.requestedDeliveryDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(
        allowed.contains(current) ? current! : available.first,
      ),
      firstDate: DateTime.parse(available.first),
      lastDate: DateTime.parse(available.last),
      selectableDayPredicate: (day) =>
          allowed.contains(DateFormat('yyyy-MM-dd').format(day)),
      helpText: 'Choose delivery date · Malaysia time',
    );
    return selected == null ? null : DateFormat('yyyy-MM-dd').format(selected);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(OrderService.message(error))));
    }
    return null;
  }
}
