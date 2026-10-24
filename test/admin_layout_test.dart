// ignore_for_file: subtype_of_sealed_class
import 'package:bloom_and_bunch_kl/features/admin/admin_dashboard_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_layout.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_riders_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_staff_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/rider_history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  SnapshotMetadata get metadata => _Metadata();
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  @override
  Query<Map<String, dynamic>> limit(int value) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(_Snapshot());
}

const _people = [
  {
    'uid': 'admin',
    'name': 'Protected administrator',
    'email': 'admin@example.test',
    'phone': '',
    'roles': ['admin'],
    'suspended': false,
  },
  {
    'uid': 'rider',
    'name': 'A rider with a very long display name',
    'email': 'long.staff.address@example.test',
    'phone': '',
    'roles': ['customer', 'rider'],
    'suspended': false,
  },
];
const _riders = [
  {'uid': 'idle', 'name': 'Idle rider', 'suspended': false},
  {
    'uid': 'working',
    'name': 'Delivering rider',
    'suspended': false,
    'activeDeliveryId': 'order-working',
  },
];
const _records = [
  {
    'id': 'long-order-reference-for-copy',
    'riderName': 'A rider with a long display name',
    'orderStatus': 'Awaiting Customer Confirmation',
  },
];

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'overview groups all eleven metrics into payments and operations',
    (tester) async {
      _size(tester, const Size(1920, 1200));
      await tester.pumpWidget(
        _app(AdminOverview(summaryLoader: () async => {'generatedAt': 0})),
      );
      await tester.pumpAndSettle();
      final cards = find.descendant(
        of: find.byType(AdminMetricGrid),
        matching: find.byType(Card),
      );
      expect(cards, findsNWidgets(11));
      final sizes = List.generate(11, (i) => tester.getSize(cards.at(i)));
      expect(sizes.take(3).every((size) => size == sizes.first), isTrue);
      expect(sizes.skip(3).every((size) => size == sizes[3]), isTrue);
      final tops = List.generate(11, (i) => tester.getTopLeft(cards.at(i)).dy);
      expect(tops.take(3).toSet().length, 1);
      expect(tops.skip(3).take(4).toSet().length, 1);
      expect(tops.skip(7).take(4).toSet().length, 1);
      expect(tops[3], greaterThan(tops[0]));
      expect(tops[7], greaterThan(tops[3]));
      expect(
        tester.getTopLeft(cards.at(7)).dx,
        tester.getTopLeft(cards.first).dx,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rider directory offers contact review for every rider and paginates using its cursor',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final requests = <String?>[];
      await tester.pumpWidget(
        _app(
          AdminRiderDirectory(
            ridersLoader: (after) async {
              requests.add(after);
              return {
                'riders': _riders,
                'next': after == null ? 'next-rider' : null,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
      expect(find.textContaining('No recent shared locations'), findsOneWidget);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests.last, 'next-rider');
      expect(find.text('Page 2'), findsOneWidget);
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(requests.last, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'staff desktop separates roles, access and missing phone values',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      await tester.pumpWidget(
        _app(AdminStaffScreen(peopleLoader: (_) async => {'people': _people})),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(
        find.byTooltip('Administrator access is protected'),
        findsOneWidget,
      );
      expect(find.text('Roles'), findsOneWidget);
      expect(find.text('Access'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop history abbreviates IDs and opens the selected order', (
    tester,
  ) async {
    _size(tester, const Size(1440, 1000));
    String? opened;
    await tester.pumpWidget(
      _app(
        AdminPage(
          child: ListView(
            children: [
              AdminDeliveryRecords(
                records: _records,
                onOpen: (id) => opened = id,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('#long-ord…'), findsOneWidget);
    expect(find.byTooltip('Copy full order ID'), findsOneWidget);
    await tester.tap(find.text('View'));
    expect(opened, _records.first['id']);
    expect(find.text('Not recorded'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('embedded history has one heading and no nested app bar', (
    tester,
  ) async {
    _size(tester, const Size(1440, 1000));
    await tester.pumpWidget(
      _app(
        RiderHistoryScreen(
          embedded: true,
          queryOverride: _Query(),
          ridersLoader: (_) async => {'riders': [], 'next': null},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Delivery history'), findsOneWidget);
    expect(find.text('No deliveries match these filters.'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 768.0]) {
    testWidgets(
      'admin layouts fit width $width with double text and reachable pagination',
      (tester) async {
        _size(tester, Size(width, 800));
        final screens = [
          AdminOverview(summaryLoader: () async => {'generatedAt': 0}),
          AdminRiderDirectory(ridersLoader: (_) async => {'riders': _riders}),
          AdminStaffScreen(peopleLoader: (_) async => {'people': _people}),
          RiderHistoryScreen(
            embedded: true,
            queryOverride: _Query(),
            ridersLoader: (_) async => {'riders': [], 'next': null},
          ),
          AdminPage(
            child: ListView(
              children: [
                AdminDeliveryRecords(records: _records, onOpen: (_) {}),
              ],
            ),
          ),
        ];
        for (final screen in screens) {
          await tester.pumpWidget(_app(screen, scale: 2));
          await tester.pumpAndSettle();
          expect(find.byType(DataTable), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType}',
          );
          if (screen is AdminRiderDirectory ||
              screen is AdminStaffScreen ||
              screen is RiderHistoryScreen) {
            await tester.scrollUntilVisible(
              find.text('Page 1'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }
}
