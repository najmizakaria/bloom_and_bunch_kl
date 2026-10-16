import 'dart:async';
import 'package:bloom_and_bunch_kl/core/widgets/phone_number_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openPhone(
  WidgetTester tester,
  Future<void> Function(String) save, {
  void Function(bool?)? result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    PhoneNumberDialog(currentPhone: '', onSave: save),
              );
              result?.call(saved);
            },
            child: const Text('Edit phone'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Edit phone'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('save keeps the controller alive through the closing animation', (
    tester,
  ) async {
    String? phone;
    bool? saved;
    await openPhone(tester, (value) async {
      phone = value;
    }, result: (value) => saved = value);
    await tester.enterText(find.byType(TextField), ' 0123456789 ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(phone, '0123456789');
    expect(saved, true);
    expect(find.byType(PhoneNumberDialog), findsNothing);
    expect(find.text('Edit phone'), findsOneWidget);
  });

  testWidgets(
    'cancel discards edits and closes without controller exceptions',
    (tester) async {
      var writes = 0;
      await openPhone(tester, (_) async {
        writes++;
      });
      await tester.enterText(find.byType(TextField), '0123456789');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(writes, 0);
      expect(find.byType(PhoneNumberDialog), findsNothing);
    },
  );

  testWidgets('failed save retains the phone and allows retry', (tester) async {
    var calls = 0;
    await openPhone(tester, (_) async {
      if (++calls == 1) throw StateError('offline');
    });
    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your phone number. Please retry.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '0123456789',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(PhoneNumberDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending save blocks duplicate writes and back dismissal', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await openPhone(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    final context = tester.element(find.byType(PhoneNumberDialog));
    await Navigator.of(context).maybePop();
    await tester.pump();
    expect(find.byType(PhoneNumberDialog), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(PhoneNumberDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal during an in-flight save does not pop another route', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openPhone(tester, (_) => pending.future);
    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
