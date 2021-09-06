// This is a basic Flutter widget test.
//
// Instead of testing MyStateNotifier here, we test the UI that uses it.

import 'package:example/main.dart';
import 'package:example/my_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Logger>(create: (_) => LoggerMock()),
          StateNotifierProvider<MyStateNotifier, MyState>(
            create: (_) => MyStateNotifier(),
          ),
        ],
        child: MyApp(),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1000'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1000'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

class LoggerMock extends Mock implements Logger {}
