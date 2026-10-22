import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_inventory_screen.dart';
import 'package:bloom_and_bunch_kl/models/flower_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FlowerModel _flower(int stock) => FlowerModel(
  flowerId: 'lily',
  name: 'White Lily',
  category: 'Lilies',
  pricePerStem: 18,
  stockQuantity: stock,
  reservedQuantity: 2,
  imageUrl: '',
);

Future<void> _mount(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  int stock = 12,
  VoidCallback? decrease,
  VoidCallback? increase,
  ValueChanged<bool>? availability,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: AppTypography.textTheme,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: FlowerInventoryCard(
            flower: _flower(stock),
            onEdit: () {},
            onDecreaseStock: decrease ?? () {},
            onIncreaseStock: increase ?? () {},
            onAvailabilityChanged: availability ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'stock controls stay together and custom orders is bottom right at $width / $scale',
        (tester) async {
          await _mount(tester, width: width, scale: scale);
          await tester.ensureVisible(find.byType(Switch));
          final minus = tester.getCenter(find.byTooltip('Decrease stock'));
          final quantity = tester.getCenter(find.text('12'));
          final plus = tester.getCenter(find.byTooltip('Increase stock'));
          expect(minus.dy, closeTo(quantity.dy, .1));
          expect(plus.dy, closeTo(quantity.dy, .1));
          expect(minus.dx, lessThan(quantity.dx));
          expect(plus.dx, greaterThan(quantity.dx));
          expect(
            tester.getTopLeft(find.byType(Switch)).dy,
            greaterThanOrEqualTo(
              tester.getBottomLeft(find.byTooltip('Increase stock')).dy,
            ),
          );
          expect(
            tester.getBottomRight(find.byType(Switch)).dx,
            closeTo(tester.getBottomRight(find.byType(Card)).dx - 12, .1),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'large stock values fit the compact stepper at double text size',
    (tester) async {
      await _mount(tester, width: 320, scale: 2, stock: 999999);
      await tester.ensureVisible(find.text('999999'));
      expect(
        tester.getCenter(find.text('999999')).dy,
        closeTo(tester.getCenter(find.byTooltip('Increase stock')).dy, .1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stock buttons and custom availability retain their actions', (
    tester,
  ) async {
    var decreases = 0, increases = 0;
    bool? availability;
    await _mount(
      tester,
      width: 390,
      decrease: () => decreases++,
      increase: () => increases++,
      availability: (value) => availability = value,
    );
    await tester.tap(find.byTooltip('Decrease stock'));
    await tester.tap(find.byTooltip('Increase stock'));
    await tester.tap(find.byType(Switch));
    expect(decreases, 1);
    expect(increases, 1);
    expect(availability, false);
    await _mount(tester, width: 390, stock: 0);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
