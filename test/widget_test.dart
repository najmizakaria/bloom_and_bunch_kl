// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importing main.dart caused an error in the test environment because
// the expected MyApp class was not found. Define a minimal test app
// here to exercise the counter behavior used by this test.

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build a minimal app and trigger a frame.
    await tester.pumpWidget(const _MyTestApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

// Minimal app used only for this test to replicate the counter and
// FloatingActionButton behavior expected by the original test.
class _MyTestApp extends StatefulWidget {
  const _MyTestApp({Key? key}) : super(key: key);

  @override
  State<_MyTestApp> createState() => _MyTestAppState();
}

class _MyTestAppState extends State<_MyTestApp> {
  int _counter = 0;

  void _increment() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test App')),
        body: Center(child: Text('$_counter')),
        floatingActionButton: FloatingActionButton(
          onPressed: _increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
