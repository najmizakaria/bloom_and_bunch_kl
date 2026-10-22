import 'dart:async';
import 'package:bloom_and_bunch_kl/core/widgets/map_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'late SDK authorization failure replaces the map and supports retry',
    (tester) async {
      final failures = StreamController<void>.broadcast();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 250,
              child: MapAccess(
                load: () async {
                  calls++;
                },
                failures: failures.stream,
                child: const Text('Map content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Map content'), findsOneWidget);
      failures.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Map content'), findsNothing);
      expect(find.textContaining('map could not load'), findsOneWidget);
      await tester.tap(find.text('Retry map'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Map content'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(failures.hasListener, false);
      await failures.close();
    },
  );

  testWidgets(
    'failed SDK load provides a reachable fallback at large text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              height: 250,
              child: MapAccess(
                load: () async => throw StateError('SDK network failure'),
                child: const Text('Map content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Map content'), findsNothing);
      await tester.ensureVisible(find.text('Retry map'));
      expect(find.text('Retry map').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
