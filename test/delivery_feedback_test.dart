// Firestore interfaces are mocked only to exercise UI list loading.
import 'dart:async';
// ignore_for_file: subtype_of_sealed_class
import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/utils/malaysia_time.dart';
import 'package:bloom_and_bunch_kl/core/widgets/delivery_progress.dart';
import 'package:bloom_and_bunch_kl/core/widgets/firestore_page.dart';
import 'package:bloom_and_bunch_kl/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Metadata implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final int number;
  _Doc(this.number);
  @override
  String get id => '$number';
  @override
  Map<String, dynamic> data() => {'number': number};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _Snapshot(this.docs);
  @override
  SnapshotMetadata get metadata => _Metadata();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Query implements Query<Map<String, dynamic>> {
  final List<_Doc> all;
  final int start, size;
  _Query(this.all, {this.start = 0, this.size = 100});
  @override
  Query<Map<String, dynamic>> limit(int value) =>
      _Query(all, start: start, size: value);
  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot<Object?> snapshot,
  ) => _Query(all, start: int.parse(snapshot.id) + 1, size: size);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(
    _Snapshot(all.where((d) => d.number >= start).take(size).toList()),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingQuery extends _Query {
  _PendingQuery(this.controller) : super([]);
  final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
  @override
  Query<Map<String, dynamic>> limit(int value) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => controller.stream;
}

void main() {
  test(
    'awaiting receipt stays active and Completed remains distinct from legacy Delivered',
    () {
      expect(OrderStatuses.isPast(OrderStatuses.awaitingConfirmation), isFalse);
      expect(OrderStatuses.normalize('Completed'), 'Completed');
      expect(OrderStatuses.isPast('Delivered'), isTrue);
      expect(OrderStatuses.isPast('Completed'), isTrue);
    },
  );
  test(
    'Malaysia date formatting and date boundaries do not depend on host timezone',
    () {
      expect(
        malaysiaTime(DateTime.utc(2026, 10, 4, 17)),
        '5 Oct 2026, 1:00 AM MYT',
      );
      expect(
        malaysiaDateBoundary(DateTime(2026, 10, 5)),
        DateTime.utc(2026, 10, 4, 16),
      );
    },
  );
  test(
    'malformed roles fail loading rather than opening a fallback dashboard',
    () {
      expect(() => UserModel.fromMap({}), throwsFormatException);
      expect(
        UserModel.fromMap({
          'roles': ['rider'],
        }).activeRole,
        'rider',
      );
      expect(
        () => UserModel.fromMap({'role': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => UserModel.fromMap({
          'role': 'customer',
          'roles': ['admin', 1],
        }),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'ready delivery progress includes packing and legacy history does not imply receipt',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryProgress(
                status: 'Awaiting Customer Confirmation',
                fulfillmentType: 'ready_now',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Bouquet being prepared'), findsOneWidget);
      expect(find.text('Current status'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        lessThan(1),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryProgress(
              status: 'Delivered',
              fulfillmentType: 'custom',
            ),
          ),
        ),
      );
      expect(find.textContaining('was not recorded'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'receipt cancellation submits nothing, confirmation submits once and open issues disable it',
    (tester) async {
      var calls = 0;
      Future<void> mount(bool issue) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptConfirmation(
              busy: false,
              hasOpenIssue: issue,
              onConfirm: () async {
                calls++;
              },
            ),
          ),
        ),
      );
      await mount(false);
      await tester.tap(find.text('Confirm received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Confirm received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm received').last);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await mount(true);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'delivery UI remains scrollable at 320 pixels and double text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const DeliveryProgress(
                      status: 'Awaiting Customer Confirmation',
                      fulfillmentType: 'custom',
                    ),
                    ReceiptConfirmation(
                      busy: false,
                      hasOpenIssue: true,
                      onConfirm: () async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'records append on scroll without page controls and reload floats',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirestorePage(
              query: _Query(List.generate(43, _Doc.new)),
              builder: (context, docs) => SingleChildScrollView(
                child: Column(
                  children: [
                    for (final doc in docs)
                      SizedBox(height: 72, child: Text('Record ${doc.id}')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record 19'), findsOneWidget);
      expect(find.text('Record 20'), findsNothing);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Page 1'), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record 0'), findsOneWidget);
      expect(find.text('Record 39'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record 42'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reload'));
      await tester.pumpAndSettle();
      expect(find.text('Record 0'), findsOneWidget);
      expect(find.text('Record 20'), findsNothing);
      expect(
        tester.getCenter(find.byTooltip('Reload')).dx,
        lessThan(
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        ),
      );
    },
  );
  testWidgets(
    'floating reload stays clear of catalogue add buttons on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              label: const Text('Add Card Design'),
              icon: const Icon(Icons.add),
            ),
            body: FirestorePage(
              query: _Query([_Doc(0)]),
              builder: (context, docs) =>
                  ListView(children: const [Text('Card design')]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byTooltip('Reload'))
            .overlaps(
              tester.getRect(
                find.widgetWithText(FloatingActionButton, 'Add Card Design'),
              ),
            ),
        isFalse,
      );
      expect(tester.getCenter(find.byTooltip('Reload')).dx, lessThan(160));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'changing a query clears the previous records while waiting for new data',
    (tester) async {
      final controller =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      Widget screen(Query<Map<String, dynamic>> query) => MaterialApp(
        home: Scaffold(
          body: FirestorePage(
            query: query,
            builder: (context, docs) => ListView(
              children: [for (final doc in docs) Text('Record ${doc.id}')],
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(_Query([_Doc(0)])));
      await tester.pumpAndSettle();
      expect(find.text('Record 0'), findsOneWidget);
      await tester.pumpWidget(screen(_PendingQuery(controller)));
      await tester.pump();
      expect(find.text('Record 0'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(controller.hasListener, isTrue);
      controller.add(_Snapshot([_Doc(999)]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Record 999'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.close();
    },
  );
}
