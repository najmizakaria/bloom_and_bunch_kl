import 'package:bloom_and_bunch_kl/features/florist/screens/commerce_catalogue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester tester, {
  required bool isCard,
  int stock = 12,
  bool busy = false,
  VoidCallback? edit,
  VoidCallback? increase,
  ValueChanged<bool>? publish,
}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CommerceInventoryCard(
            product: {
              'name': isCard
                  ? 'Lots of Love'
                  : 'Ferrero Rocher Chocolate (24 pcs)',
              'category': 'Chocolates',
              'price': 30,
              'stockQuantity': stock,
              'isPublished': true,
              'imageUrl': '',
            },
            isCard: isCard,
            busy: busy,
            onEdit: edit ?? () {},
            onDecreaseStock: () {},
            onIncreaseStock: increase ?? () {},
            onPublishedChanged: publish ?? (_) {},
          ),
        ),
      ),
    ),
  );
  // A pending save deliberately displays an animated progress indicator.
  await tester.pump();
}

void main() {
  testWidgets(
    'add-on management fits narrow large text and its controls work',
    (tester) async {
      var edits = 0, additions = 0;
      bool? published;
      await mount(
        tester,
        isCard: false,
        edit: () => edits++,
        increase: () => additions++,
        publish: (value) => published = value,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('RM 30.00'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit add-on'));
      await tester.ensureVisible(find.byTooltip('Increase stock'));
      await tester.tap(find.byTooltip('Increase stock'));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      expect(edits, 1);
      expect(additions, 1);
      expect(published, false);
      final minus = tester.getCenter(find.byTooltip('Decrease stock'));
      final plus = tester.getCenter(find.byTooltip('Increase stock'));
      expect(minus.dy, closeTo(plus.dy, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card management has publishing and edit without stock controls',
    (tester) async {
      await mount(tester, isCard: true);
      expect(find.byTooltip('Edit card design'), findsOneWidget);
      expect(find.text('Message card'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byTooltip('Increase stock'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stock bounds and pending saves disable conflicting changes', (
    tester,
  ) async {
    await mount(tester, isCard: false, stock: 0);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
          )
          .onPressed,
      isNull,
    );
    await mount(tester, isCard: false, stock: 999999);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_circle_outline),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await mount(tester, isCard: false, busy: true);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.edit_outlined),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_circle_outline),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
