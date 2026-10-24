class FulfillmentTypes {
  FulfillmentTypes._();

  static const String readyNow = 'ready_now';
  static const String preOrder = 'pre_order';
  static const String custom = 'custom';

  static const List<String> values = [readyNow, preOrder, custom];

  static String customerLabel(String value) {
    switch (value) {
      case readyNow:
        return 'Ready to Send';
      case preOrder:
        return 'Pre-Order';
      case custom:
        return 'Custom Bouquet';
      default:
        return 'Order';
    }
  }
}

class OrderStatuses {
  OrderStatuses._();

  static const String awaitingPreparation = 'Awaiting Preparation';
  static const String processing = 'Processing';
  static const String readyForDelivery = 'Ready for Delivery';
  static const String outForDelivery = 'Out for Delivery';
  static const String awaitingConfirmation = 'Awaiting Customer Confirmation';
  static const String completed = 'Completed';
  static const String delivered = 'Delivered';
  static const String cancelled = 'Cancelled';

  // Kept temporarily while older Firestore orders are migrated.
  static const String legacyPending = 'Pending';

  static String normalize(String value) => switch (value) {
    legacyPending => awaitingPreparation,
    _ => value,
  };

  static bool isPast(String value) =>
      [delivered, completed, cancelled].contains(normalize(value));

  static String label(String value, {bool receiptConfirmed = false}) =>
      switch (normalize(value)) {
        awaitingPreparation => 'Order received',
        processing => 'Bouquet being prepared',
        readyForDelivery => 'Ready for rider collection',
        outForDelivery => 'Rider is delivering your order',
        awaitingConfirmation => 'Delivered — awaiting your confirmation',
        completed =>
          receiptConfirmed
              ? 'Receipt confirmed — order completed'
              : 'Completed (legacy record)',
        delivered => 'Delivered (legacy record)',
        cancelled => 'Order cancelled',
        _ => value,
      };

  static bool requiresFloristPreparation(String value) {
    return value == awaitingPreparation ||
        value == legacyPending ||
        value == processing;
  }
}
