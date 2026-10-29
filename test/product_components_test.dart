import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:bloom_and_bunch_kl/features/customer/widgets/product_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
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
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all category labels remain reachable at large text sizes', (
    tester,
  ) async {
    var selected = 'All';
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ProductFilterBar(
          children: ['All', 'Birthday', 'Anniversary', 'Romance', 'Sympathy']
              .map(
                (category) => ProductCategoryChip(
                  label: category,
                  selected: category == selected,
                  onSelected: (_) => setState(() => selected = category),
                ),
              )
              .toList(),
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isTrue,
    );
    final selectedChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'All'),
    );
    expect(selectedChip.selectedColor, AppColors.primary);
    expect(selectedChip.labelStyle?.color, AppColors.onPrimary);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-1200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sympathy'));
    await tester.pumpAndSettle();
    expect(selected, 'Sympathy');
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero and maximum quantities expose disabled controls', (
    tester,
  ) async {
    var count = 0;
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) => StemQuantityControl(
          count: count,
          onRemove: count > 0 ? () => setState(() => count--) : null,
          onAdd: count < 1 ? () => setState(() => count++) : null,
          onEdit: () {},
        ),
      ),
    );
    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      ),
    );
    expect(button('Remove one stem').onPressed, isNull);
    expect((button('Remove one stem').icon as Icon).color, isNull);
    await tester.tap(find.byTooltip('Add one stem'));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(button('Add one stem').onPressed, isNull);
    expect(button('Remove one stem').onPressed, isNotNull);
    await tester.tap(find.byTooltip('Remove one stem'));
    expect(count, 0);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'builder footer stays compact at width $width and scale $scale',
        (tester) async {
          var saves = 0;
          var adds = 0;
          await mount(
            tester,
            Column(
              children: [
                const Expanded(child: SizedBox()),
                BouquetBuilderFooter(
                  stems: 0,
                  totalPrice: 7,
                  onSave: () => saves++,
                  onAdd: () => adds++,
                ),
              ],
            ),
            width: width,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          final saveRect = tester.getRect(find.byType(OutlinedButton));
          final addRect = tester.getRect(find.byType(FilledButton));
          expect(saveRect.width, closeTo(addRect.width, 0.1));
          expect(saveRect.height, closeTo(addRect.height, 0.1));
          expect(844 - addRect.bottom, closeTo(12, 0.1));
          await tester.tap(find.text('Save Recipe'));
          await tester.tap(find.text('Continue'));
          expect(saves, 1);
          expect(adds, 1);
        },
      );
    }
  }

  testWidgets('favourite treatment stays the same when selection changes', (
    tester,
  ) async {
    var selected = false;
    await mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ProductFavouriteButton(
          selected: selected,
          onPressed: () => setState(() => selected = !selected),
        ),
      ),
    );
    final initial = tester.widget<IconButton>(find.byType(IconButton));
    final size = tester.getSize(find.byType(IconButton));
    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pumpAndSettle();
    final updated = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      updated.style!.backgroundColor!.resolve({}),
      initial.style!.backgroundColor!.resolve({}),
    );
    expect(tester.getSize(find.byType(IconButton)), size);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });
}
