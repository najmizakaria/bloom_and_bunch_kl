import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/payment_modes.dart';
import '../../../core/constants/store_details.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../core/utils/order_tracking_display.dart';
import '../../../core/widgets/page_navigation.dart';

class ViewPaymentReceiptButton extends StatelessWidget {
  const ViewPaymentReceiptButton({super.key, required this.checkoutId});

  final String checkoutId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CheckoutReceiptScreen(checkoutId: checkoutId),
      ),
    ),
    icon: const Icon(Icons.receipt_long_outlined),
    label: const Text('View receipt'),
  );
}

class CheckoutReceiptScreen extends StatefulWidget {
  const CheckoutReceiptScreen({super.key, required this.checkoutId});
  final String checkoutId;

  @override
  State<CheckoutReceiptScreen> createState() => _CheckoutReceiptScreenState();
}

class _CheckoutReceiptScreenState extends State<CheckoutReceiptScreen> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _receipt = FirebaseFirestore.instance
      .doc('users/$_uid/receipts/${widget.checkoutId}')
      .snapshots();
  late final _orders = FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: _uid)
      .where('checkoutGroupId', isEqualTo: widget.checkoutId)
      .limit(20)
      .snapshots();
  bool _exporting = false;

  Future<void> _download(PaymentReceipt receipt) async {
    setState(() => _exporting = true);
    try {
      final bytes = await receipt.pdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Bloom-and-Bunch-Receipt${receipt.filenameSuffix}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export your receipt. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.softBlushStart,
    appBar: AppBar(
      leading: const PageBackButton(),
      title: const Text('Payment receipt'),
      backgroundColor: AppColors.softBlushStart,
    ),
    body: StreamBuilder(
      stream: _receipt,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message('Could not load your receipt. Reopen to retry.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return _message('This checkout has no payment receipt.');
        }

        // Earlier receipts use the original checkout orders for missing details.
        final paidAt = data['paidAt'];
        final settledDate =
            data['paymentStatus'] == 'paid' && paidAt is Timestamp
            ? paidAt.toDate()
            : null;
        if (settledDate != null && data['deliveryAddress'] is String) {
          return _content(PaymentReceipt(data, settledDate));
        }
        return StreamBuilder(
          stream: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (settledDate != null) {
                return _content(PaymentReceipt(data, settledDate));
              }
              return _message(
                'Could not verify your payment. Reopen to retry.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = {
              for (final order in snapshot.data!.docs) order.id: order.data(),
            };
            final ids =
                (data['orderIds'] as List?)?.whereType<String>() ??
                const <String>[];
            if (settledDate == null &&
                (ids.isEmpty ||
                    !ids.every(
                      (id) => orders[id]?['paymentStatus'] == 'paid',
                    ))) {
              return _message(
                'Your receipt will appear once payment is verified.',
              );
            }
            final originalPaidAt = ids
                .map((id) => orders[id]?['paidAt'])
                .whereType<Timestamp>()
                .firstOrNull;
            final deliveryOrder = ids
                .map((id) => orders[id])
                .nonNulls
                .firstOrNull;
            return _content(
              PaymentReceipt(
                data,
                settledDate ?? originalPaidAt?.toDate(),
                deliveryOrder: deliveryOrder,
              ),
            );
          },
        );
      },
    ),
  );

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _content(PaymentReceipt receipt) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _exporting ? null : () => _download(receipt),
            icon: const Icon(Icons.download_outlined),
            label: Text(_exporting ? 'Preparing PDF…' : 'Download PDF'),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    StoreDetails.name,
                    style: AppTypography.sectionTitle(),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    StoreDetails.pickupAddress,
                    style: AppTypography.supporting(color: AppColors.textMuted),
                  ),
                  const Text(
                    StoreDetails.website,
                    style: AppTypography.supporting(
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (receipt.testPayment)
                    const Text(
                      'Sandbox · Test payment',
                      style: AppTypography.supporting(
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softBlushEnd,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Amount paid',
                          style: AppTypography.label(
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          receipt.amount,
                          style: const AppTypography.total(
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (receipt.paidOn != null)
                          Text(
                            'Paid on ${receipt.paidOn}',
                            style: const AppTypography.caption(
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (receipt.paymentMethod != null)
                          Text(
                            receipt.paymentMethod!,
                            style: const AppTypography.caption(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (receipt.deliveryDetails.isNotEmpty) ...[
                    const Divider(height: 28),
                    const Text(
                      'Deliver to',
                      style: AppTypography.productTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receipt.deliveryDetails,
                      style: const AppTypography.supporting(),
                    ),
                  ],
                  for (final group in receipt.groups) ...[
                    const Divider(height: 28),
                    Text(
                      group.title,
                      style: const AppTypography.productTitle(),
                    ),
                    for (final item in group.items)
                      _amountRow(
                        item.label,
                        item.amount,
                        detail: '${item.quantity} × ${item.unitPrice}',
                      ),
                  ],
                  const Divider(height: 28),
                  for (final line in receipt.subtotals)
                    _amountRow(line.label, line.amount),
                  _amountRow('Total paid', receipt.amount, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _amountRow(
    String label,
    String amount, {
    String? detail,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: bold ? const AppTypography.productTitle() : null,
              ),
              if (detail != null)
                Text(
                  detail,
                  style: const AppTypography.caption(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            textAlign: TextAlign.end,
            style: bold ? const AppTypography.productTitle() : null,
          ),
        ),
      ],
    ),
  );
}

typedef ReceiptItem = ({
  String label,
  int quantity,
  String unitPrice,
  String amount,
});
typedef ReceiptGroup = ({String title, List<ReceiptItem> items});

class PaymentReceipt {
  PaymentReceipt(
    Map<String, dynamic> data,
    DateTime? paidAt, {
    Map<String, dynamic>? deliveryOrder,
  }) : amount = _money((data['totalSen'] as num?) ?? 0),
       paidOn = paidAt == null ? null : malaysiaTime(paidAt),
       testPayment = isOnlinePaymentMode(data['orderMode']),
       paymentMethod = switch (data['orderMode']) {
         stripeSandboxMode => 'Stripe',
         'toyyibpay_sandbox' => 'ToyyibPay',
         _ => null,
       },
       deliveryDetails = [
         ((data['recipientName'] ?? deliveryOrder?['recipientName'])
                     as String? ??
                 '')
             .trim(),
         trackingAddress(
           (data['deliveryAddress'] ?? deliveryOrder?['deliveryAddress'])
                   as String? ??
               '',
         ),
       ].where((line) => line.isNotEmpty).join('\n'),
       groups = [
         for (final group
             in (data['groups'] as List? ?? const []).whereType<Map>())
           (
             title: group['orderNumber'] is String
                 ? 'Order ${trackingOrderNumber(group['orderNumber'] as String)}'
                 : 'Items',
             items: [
               for (final item
                   in (group['items'] as List? ?? const []).whereType<Map>())
                 _item(
                  item['name']?.toString() ?? 'Item',
                   (item['quantity'] as num).toInt(),
                   ((item['unitPrice'] as num) * 100).round(),
                 ),
               if (((group['cardFeeSen'] as num?) ?? 0) > 0)
                 _item('Message card', 1, group['cardFeeSen'] as num),
             ],
           ),
       ] {
    final cardFee = _fee(data, 'cardFeeSen');
    final deliveryFee = _fee(data, 'deliveryFeeSen');
    final subtotal =
        data['subtotalSen'] as num? ??
        (data['totalSen'] as num? ?? 0) - cardFee - deliveryFee;
    subtotals = [
      (label: 'Items subtotal', amount: _money(subtotal)),
      if (cardFee > 0) (label: 'Message cards', amount: _money(cardFee)),
      if (deliveryFee > 0) (label: 'Delivery', amount: _money(deliveryFee)),
    ];
  }

  final String amount;
  final String? paidOn;
  final bool testPayment;
  final String? paymentMethod;
  final String deliveryDetails;
  final List<ReceiptGroup> groups;
  late final List<({String label, String amount})> subtotals;
  String get filenameSuffix {
    final title = groups.firstOrNull?.title ?? '';
    final number = RegExp(
      r'^Order #([A-Za-z0-9]+)$',
    ).firstMatch(title)?.group(1);
    return number == null ? '' : '-$number';
  }

  static String _money(num sen) => 'RM ${(sen / 100).toStringAsFixed(2)}';

  static ReceiptItem _item(String label, int quantity, num unitSen) => (
    label: label,
    quantity: quantity,
    unitPrice: _money(unitSen),
    amount: _money(unitSen * quantity),
  );

  static num _fee(Map<String, dynamic> data, String key) =>
      data[key] as num? ??
      (data['groups'] as List? ?? const []).whereType<Map>().fold<num>(
        0,
        (total, group) => total + (group[key] as num? ?? 0),
      );

  Future<Uint8List> pdf() async {
    final document = pw.Document();
    final brown = PdfColor.fromHex('#754C39');
    final heading = pw.TextStyle(fontSize: 13, color: brown);
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/nunito/Nunito-VariableFont_wght.ttf'),
    );
    pw.Widget amountRow(String label, String amount) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.SizedBox(width: 16),
          pw.Text(amount),
        ],
      ),
    );
    pw.Widget itemRow(
      String label,
      String quantity,
      String unitPrice,
      String amount, {
      pw.TextStyle? style,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          for (final (value, width) in [
            (quantity, 42.0),
            (unitPrice, 87.0),
            (amount, 87.0),
          ])
            pw.SizedBox(
              width: width,
              child: pw.Text(
                value,
                style: style,
                textAlign: pw.TextAlign.right,
              ),
            ),
        ],
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          pw.Text(
            StoreDetails.name,
            style: pw.TextStyle(
              fontSize: 24,
              color: brown,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(StoreDetails.pickupAddress),
          pw.Text(StoreDetails.website),
          pw.SizedBox(height: 16),
          pw.Text(
            'Payment receipt',
            style: pw.TextStyle(fontSize: 20, color: brown),
          ),
          if (testPayment) pw.Text('Test payment · Sandbox'),
          if (paidOn != null) pw.Text('Paid on $paidOn'),
          if (paymentMethod != null) pw.Text('Paid via $paymentMethod'),
          if (deliveryDetails.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Deliver to', style: heading),
            pw.Text(deliveryDetails),
          ],
          for (final group in groups) ...[
            pw.Divider(color: PdfColors.grey300),
            pw.Text(group.title, style: heading),
            itemRow('Item', 'Qty', 'Unit price', 'Amount', style: heading),
            for (final item in group.items)
              itemRow(
                item.label,
                '${item.quantity}',
                item.unitPrice,
                item.amount,
              ),
          ],
          pw.Divider(color: brown),
          for (final line in subtotals) amountRow(line.label, line.amount),
          amountRow('Total paid', amount),
        ],
      ),
    );
    return document.save();
  }
}
