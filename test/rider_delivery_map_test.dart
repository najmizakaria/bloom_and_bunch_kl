import 'dart:async';

import 'package:bloom_and_bunch_kl/features/rider/screens/rider_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/rider_delivery_details.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class _Maps extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) => const ColoredBox(color: Colors.transparent);
}

OrderModel _order({
  double? latitude = 2.99,
  String status = 'Out for Delivery',
}) => OrderModel.fromMap({
  'deliveryAddress': 'Jalan Test, Kajang, Selangor',
  'recipientName': 'Recipient',
  'recipientPhone': '0123456789',
  'orderStatus': status,
  'latitude': latitude,
  'longitude': latitude == null ? null : 101.78,
}, 'test_delivery');

Widget _card(OrderModel order) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: RiderDeliveryDetails(order: order)),
  ),
);

void main() {
  late GoogleMapsFlutterPlatform originalMaps;
  setUp(() {
    originalMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = _Maps();
  });
  tearDown(() => GoogleMapsFlutterPlatform.instance = originalMaps);

  testWidgets('destination preview comes first inside the delivery card', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_order()));
    await tester.pumpAndSettle();

    final mapFinder = find.byType(GoogleMap);
    final map = tester.widget<GoogleMap>(mapFinder);
    expect(
      find.ancestor(of: mapFinder, matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(
      tester.getBottomLeft(mapFinder).dy,
      lessThan(tester.getTopLeft(find.textContaining('Delivery #')).dy),
    );
    expect(tester.getSize(mapFinder).height, 220);
    expect(map.initialCameraPosition.target, const LatLng(2.99, 101.78));
    expect(map.markers.single.position, map.initialCameraPosition.target);
    expect(map.scrollGesturesEnabled, isFalse);
    expect(map.zoomGesturesEnabled, isFalse);
    expect(map.rotateGesturesEnabled, isFalse);
    expect(map.tiltGesturesEnabled, isFalse);

    await tester.drag(mapFinder, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(mapFinder).dy, lessThan(0));
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Call recipient'), findsOneWidget);
  });

  testWidgets('a changed destination replaces the map camera and pin', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_order()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_card(_order(latitude: 3.1)));
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.initialCameraPosition.target, const LatLng(3.1, 101.78));
    expect(map.markers.single.position, const LatLng(3.1, 101.78));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing coordinates keep address, retry and navigation available',
    (tester) async {
      await tester.pumpWidget(_card(_order(latitude: null)));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsNothing);
      expect(
        find.text('Map unavailable. Use the written delivery address.'),
        findsOneWidget,
      );
      expect(find.text('Jalan Test, Kajang, Selangor'), findsOneWidget);
      await tester.tap(find.text('Retry map'));
      await tester.pumpAndSettle();
      expect(find.text('Navigate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail screen has one map and follows live delivery actions', (
    tester,
  ) async {
    final orders = StreamController<OrderModel>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: RiderOrderDetailScreen(
          order: _order(status: 'Rider assigned'),
          watch: (_) => orders.stream,
        ),
      ),
    );
    orders.add(_order(status: 'Rider assigned'));
    await tester.pumpAndSettle();
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Confirm collection'), findsOneWidget);

    orders.add(_order());
    await tester.pumpAndSettle();
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Mark as Delivered'), findsOneWidget);

    orders.add(_order(status: 'Awaiting Customer Confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as Delivered'), findsNothing);
    expect(
      find.textContaining('Waiting for customer receipt confirmation.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await orders.close();
  });
}
