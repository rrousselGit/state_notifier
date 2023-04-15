import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state = state + 1;
}

void main() {
  group('MultiStateNotifierListener', () {
    testWidgets('calls listeners on state changes', (tester) async {
      final statesA = <int>[];
      const expectedStatesA = [1, 2];
      final counterNotifierA = CounterNotifier();

      final statesB = <int>[];
      final expectedStatesB = [1];
      final counterNotifierB = CounterNotifier();

      await tester.pumpWidget(
        MultiStateNotifierListener(
          listeners: [
            StateNotifierListener<CounterNotifier, int>(
              value: counterNotifierA,
              listener: (context, state) => statesA.add(state),
            ),
            StateNotifierListener<CounterNotifier, int>(
              value: counterNotifierB,
              listener: (context, state) => statesB.add(state),
            ),
          ],
          child:
              const SizedBox(key: Key('multi_state_notifier_listener_child')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('multi_state_notifier_listener_child')),
          findsOneWidget);

      counterNotifierA.increment();
      await tester.pump();
      counterNotifierA.increment();
      await tester.pump();
      counterNotifierB.increment();
      await tester.pump();

      expect(statesA, expectedStatesA);
      expect(statesB, expectedStatesB);
    });

    testWidgets('calls listeners on state changes without explicit types',
        (tester) async {
      final statesA = <int>[];
      const expectedStatesA = [1, 2];
      final counterNotifierA = CounterNotifier();

      final statesB = <int>[];
      final expectedStatesB = [1];
      final counterNotifierB = CounterNotifier();

      await tester.pumpWidget(
        MultiStateNotifierListener(
          listeners: [
            StateNotifierListener<CounterNotifier, int>(
              value: counterNotifierA,
              listener: (context, state) => statesA.add(state),
            ),
            StateNotifierListener<CounterNotifier, int>(
              value: counterNotifierB,
              listener: (context, state) => statesB.add(state),
            ),
          ],
          child:
              const SizedBox(key: Key('multi_state_notifier_listener_child')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('multi_state_notifier_listener_child')),
          findsOneWidget);

      counterNotifierA.increment();
      await tester.pump();
      counterNotifierA.increment();
      await tester.pump();
      counterNotifierB.increment();
      await tester.pump();

      expect(statesA, expectedStatesA);
      expect(statesB, expectedStatesB);
    });
  });
}
