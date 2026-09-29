import 'package:flutter/material.dart';

class LegalDocuments {
  static const termsTitle = 'Terms of Service';
  static const privacyTitle = 'Privacy Policy';
  static const terms = '''Bloom & Bunch KL — service information

Choose a published bouquet or build a custom bouquet. Ready-now availability depends on ready stock. Pre-orders and custom bouquets require preparation. The checkout screen shows the current price; the server confirms price and availability before creating an order. Review the recipient, phone number, delivery address, map pin and card message before confirming.

An order remains active while it is being prepared or delivered. Estimated dispatch dates follow the configured store calendar and are not guaranteed arrival times. Checkout shows delivery fees and payment instructions. Demo orders do not collect payment or book a real delivery. Contact the store through Profile for changes, cancellation requests, delivery questions, or problems with an order. The app does not process a payment or promise a refund automatically.

Keep your sign-in details private and provide accurate recipient information. Account deletion requires identity confirmation and completion of active orders or assigned deliveries. You can contact the store at +60 14-837 6919.

These service details describe the app's current behavior. Store-specific payment, cancellation and refund terms must be confirmed with the store before placing an order.''';
  static const privacy = '''Bloom & Bunch KL — data use

The app uses Firebase Authentication for email/password or Google sign-in. A profile stores your name, email, phone number and account roles. Saved addresses contain recipient details, delivery notes and optional coordinates. Orders store the selected products, quantities, prices, delivery details and card message. Optional feedback and support requests are linked to an order and visible to authorised store staff. Avoid including sensitive information in comments. Feedback and support content is removed when the associated customer account is deleted. Favourites and recipes are linked to your account.

Builds with monitoring enabled use Firebase Analytics for basic usage events and error categories, and Crashlytics on supported native platforms for diagnostic reports. App event payloads exclude addresses, phone numbers and card messages. Monitoring is disabled in local demos and disabled by default until the store enables it.

Location access is used when you choose to detect your location. You can enter an address and confirm a delivery pin instead. Camera and photo access are used when staff choose product images. Notification permission is optional. Enabling notifications saves a device token and your preference so the app can send order-status updates. You can disable them in Profile or your device settings.

Authorised store staff can access orders for fulfilment; the assigned rider can access delivery details. Firebase services process authentication, database, image-storage and notification data. Your cart and a pending checkout retry are stored on your device under your account. Signing out hides that cart from other accounts on the same device.

Account deletion removes your authentication account, profile, saved addresses, favourites, recipes, rider application and registered notification devices. Historical orders are retained for store records with your account identifiers, recipient details, delivery address, coordinates and card messages removed. A deletion-job record is retained to complete cleanup reliably. A local cart is also removed after successful deletion. Device/browser backups and previously received notifications are controlled by your device.

For questions about your information, contact the store at +60 14-837 6919.''';
  static Future<void> show(BuildContext context, String title) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(title == privacyTitle ? privacy : terms),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}

class PolicyLinks extends StatelessWidget {
  const PolicyLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () =>
            LegalDocuments.show(context, LegalDocuments.termsTitle),
        child: const Text('Terms of Service'),
      ),
      TextButton(
        onPressed: () =>
            LegalDocuments.show(context, LegalDocuments.privacyTitle),
        child: const Text('Privacy Policy'),
      ),
    ],
  );
}
