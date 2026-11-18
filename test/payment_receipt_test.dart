import 'dart:convert';
import 'dart:io';

import 'package:bloom_and_bunch_kl/features/customer/screens/checkout_receipt_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'receipt keeps the combined total and exports an itemized sandbox PDF',
    () async {
      final receipt = PaymentReceipt({
        'orderMode': 'stripe_sandbox',
        'totalSen': 3000,
        'recipientName': 'Test Recipient',
        'deliveryAddress': 'WQMX+JV, 12 Jalan Melati, Kajang, Selangor, Kajang',
        'groups': [
          {
            'orderNumber': '#ORDER0001',
            'items': [
              {'name': 'Garden Rose Bouquet', 'quantity': 2, 'unitPrice': 10},
            ],
          },
          {
            'orderNumber': '#ORDER0002',
            'cardFeeSen': 100,
            'items': [
              {'name': 'Chocolate', 'quantity': 1, 'unitPrice': 9},
            ],
          },
        ],
      }, DateTime.utc(2026, 11, 19));

      expect(receipt.amount, 'RM 30.00');
      expect(receipt.paidOn, contains('19 Nov 2026'));
      expect(receipt.testPayment, isTrue);
      expect(receipt.paymentMethod, 'Stripe');
      expect(
        receipt.deliveryDetails,
        'Test Recipient\n12 Jalan Melati, Kajang, Selangor',
      );
      expect(receipt.filenameSuffix, '-0001');
      expect(receipt.groups.first.items.single.quantity, 2);
      expect(receipt.groups.first.items.single.unitPrice, 'RM 10.00');
      expect(receipt.groups.first.items.single.amount, 'RM 20.00');
      expect(receipt.groups.last.items.last.amount, 'RM 1.00');
      expect(receipt.subtotals, [
        (label: 'Items subtotal', amount: 'RM 29.00'),
        (label: 'Message cards', amount: 'RM 1.00'),
      ]);
      final bytes = await receipt.pdf();
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      if (Platform.environment['BLOOM_RECEIPT_PREVIEW']
          case final String path) {
        await File(path).writeAsBytes(bytes);
      }
    },
  );
  test(
    'earlier receipts can use delivery details from their checkout order',
    () {
      final receipt = PaymentReceipt(
        {'totalSen': 700},
        null,
        deliveryOrder: {
          'recipientName': 'Legacy Recipient',
          'deliveryAddress': 'Kuala Lumpur',
        },
      );
      expect(receipt.deliveryDetails, 'Legacy Recipient\nKuala Lumpur');
      expect(receipt.subtotals.single.amount, 'RM 7.00');
      expect(receipt.paymentMethod, isNull);
    },
  );
}
