import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'common.dart';

void main() {
  testWidgets('rebuilds when value changes', (tester) async {
    final notifier = TestNotifier(0);
    final child = Container();

    await tester.pumpWidget(
      StateNotifierBuilder<int>(
        stateNotifier: notifier,
        builder: (context, value, c) {
          assert(child == c, '');
          return Text('$value', textDirection: TextDirection.ltr);
        },
        child: child,
      ),
    );

    expect(find.text('0'), findsOneWidget);

    notifier.increment();

    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('disposes sub', (tester) async {
    final notifier = TestNotifier(0);

    expect(notifier.hasListeners, isFalse);

    await tester.pumpWidget(
      StateNotifierBuilder<int>(
        stateNotifier: notifier,
        builder: (context, value, c) {
          return Text('$value', textDirection: TextDirection.ltr);
        },
      ),
    );

    expect(notifier.hasListeners, isTrue);
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(Container());

    expect(notifier.hasListeners, isFalse);
  });

  testWidgets('change notifier', (tester) async {
    final notifier = TestNotifier(0);

    expect(notifier.hasListeners, isFalse);

    await tester.pumpWidget(
      StateNotifierBuilder<int>(
        stateNotifier: notifier,
        builder: (context, value, c) {
          return Text('$value', textDirection: TextDirection.ltr);
        },
      ),
    );

    expect(notifier.hasListeners, isTrue);
    expect(find.text('0'), findsOneWidget);

    final notifier2 = TestNotifier(1);

    await tester.pumpWidget(
      StateNotifierBuilder<int>(
        stateNotifier: notifier2,
        builder: (context, value, c) {
          return Text('$value', textDirection: TextDirection.ltr);
        },
      ),
    );

    expect(notifier.hasListeners, isFalse);
    expect(notifier2.hasListeners, isTrue);
    expect(find.text('1'), findsOneWidget);

    notifier2.increment();

    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });
  testWidgets('debugFillProperties', (tester) async {
    final notifier = TestNotifier(0);
    final child = StateNotifierBuilder<int>(
      stateNotifier: notifier,
      builder: (context, value, c) {
        return Text('$value', textDirection: TextDirection.ltr);
      },
    );

    expect(
      child.toString(),
      "StateNotifierBuilder<int>(stateNotifier: Instance of 'TestNotifier', child: null, has builder)",
    );

    await tester.pumpWidget(child);

    final state = tester.state(find.byWidget(child));

    expect(state.toString(), endsWith('(state: 0)'));

    notifier.increment();

    expect(state.toString(), endsWith('(state: 1)'));
  });
}
