import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_and_bunch_kl/core/widgets/load_more_on_scroll.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_widgets.dart';

void main() {
  testWidgets(
    'short filtered lists keep loading even when their height does not change',
    (tester) async {
      var batches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LoadMoreOnScroll(
                hasMore: batches < 3,
                busy: false,
                onLoad: () => setState(() => batches++),
                child: ListView(children: const [Text('Filtered results')]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(batches, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading more can fail and retry without discarding existing records',
    (tester) async {
      var failed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminLoad(
              recordsKey: 'items',
              loadPage: (cursor) async {
                if (cursor != null && !failed) {
                  failed = true;
                  throw StateError('Connection interrupted');
                }
                return {
                  'items': cursor == null
                      ? List.generate(20, (i) => 'Item $i')
                      : ['Item 20'],
                  'next': cursor == null ? 'more' : null,
                };
              },
              builder: (data, refresh) => ListView(
                children: [
                  for (final item in data['items'] as List)
                    SizedBox(height: 80, child: Text(item as String)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(find.text('Retry loading more'), findsOneWidget);
      expect(find.text('Item 19'), findsOneWidget);
      await tester.tap(find.text('Retry loading more'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0),
      );
      await tester.scrollUntilVisible(
        find.text('Item 20'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Item 20'), findsOneWidget);
      expect(find.text('Retry loading more'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.byTooltip('Reload'), findsOneWidget);
    },
  );
}
