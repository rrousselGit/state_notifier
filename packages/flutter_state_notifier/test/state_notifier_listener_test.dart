import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier({int seed = 0}) : super(seed);

  void increment() => state = state + 1;
}

class CounterApp extends StatefulWidget {
  const CounterApp({Key? key, this.onListenerCalled}) : super(key: key);

  final StateNotifierWidgetListener<int>? onListenerCalled;

  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  late CounterNotifier _counterNotifier;

  @override
  void initState() {
    super.initState();
    _counterNotifier = CounterNotifier();
  }

  @override
  void dispose() {
    _counterNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: StateNotifierListener<CounterNotifier, int>(
          stateNotifier: _counterNotifier,
          listener: (context, state) {
            widget.onListenerCalled?.call(context, state);
          },
          child: Column(
            children: [
              ElevatedButton(
                key: const Key('state_notifier_listener_increment_button'),
                child: const SizedBox(),
                onPressed: () => _counterNotifier.increment(),
              ),
              ElevatedButton(
                key: const Key('state_notifier_listener_reset_button'),
                child: const SizedBox(),
                onPressed: () {
                  setState(() => _counterNotifier = CounterNotifier());
                },
              ),
              ElevatedButton(
                key: const Key('state_notifier_listener_noop_button'),
                child: const SizedBox(),
                onPressed: () {
                  setState(() => _counterNotifier = _counterNotifier);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('StateNotifierListener', () {
    testWidgets('renders child properly', (tester) async {
      const targetKey = Key('state_notifier_listener_container');
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: CounterNotifier(),
          listener: (_, __) {},
          child: const SizedBox(key: targetKey),
        ),
      );
      expect(find.byKey(targetKey), findsOneWidget);
    });

    testWidgets('calls listener on single state change', (tester) async {
      final counterNotifier = CounterNotifier();
      final states = <int>[];
      const expectedStates = [1];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listener: (_, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();
      expect(states, expectedStates);
    });

    testWidgets('calls listener on multiple state change', (tester) async {
      final counterNotifier = CounterNotifier();
      final states = <int>[];
      const expectedStates = [1, 2];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listener: (_, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      expect(states, expectedStates);
    });

    testWidgets(
        'updates when the notifier is changed at runtime to a different notifier '
        'and unsubscribes from old notifier', (tester) async {
      var listenerCallCount = 0;
      int? latestState;
      final incrementFinder = find.byKey(
        const Key('state_notifier_listener_increment_button'),
      );
      final resetNotifierFinder = find.byKey(
        const Key('state_notifier_listener_reset_button'),
      );
      await tester.pumpWidget(CounterApp(
        onListenerCalled: (_, state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(resetNotifierFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 3);
      expect(latestState, 1);
    });

    testWidgets(
        'does not update when the notifier is changed at runtime to same notifier '
        'and stays subscribed to current notifier', (tester) async {
      var listenerCallCount = 0;
      int? latestState;
      final incrementFinder = find.byKey(
        const Key('state_notifier_listener_increment_button'),
      );
      final noopNotifierFinder = find.byKey(
        const Key('state_notifier_listener_noop_button'),
      );
      await tester.pumpWidget(CounterApp(
        onListenerCalled: (context, state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(noopNotifierFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 3);
      expect(latestState, 3);
    });

    testWidgets(
        'calls listenWhen on single state change with correct previous '
        'and current states', (tester) async {
      int? latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = [1];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            latestPreviousState = previous;
            states.add(state);
            return true;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 1);
      expect(latestPreviousState, 0);
    });

    testWidgets(
        'calls listenWhen with previous listener state and current notifier state',
        (tester) async {
      int? latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = [2];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            if ((previous + state) % 3 == 0) {
              latestPreviousState = previous;
              states.add(state);
              return true;
            }
            return false;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      counterNotifier
        ..increment()
        ..increment()
        ..increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 3);
      expect(latestPreviousState, 1);
    });

    testWidgets('calls listenWhen and listener with correct state',
        (tester) async {
      final listenWhenPreviousState = <int>[];
      final listenWhenCurrentState = <int>[];
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (previous, current) {
            if (current % 3 == 0) {
              listenWhenPreviousState.add(previous);
              listenWhenCurrentState.add(current);
              return true;
            }
            return false;
          },
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterNotifier
        ..increment()
        ..increment()
        ..increment();
      await tester.pump();

      expect(states, [3]);
      expect(listenWhenPreviousState, [2]);
      expect(listenWhenCurrentState, [3]);
    });

    testWidgets(
        'calls listenWhen on multiple state change with correct previous '
        'and current states', (tester) async {
      int? latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = [1, 2];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            latestPreviousState = previous;
            states.add(state);
            return true;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 2);
      expect(latestPreviousState, 1);
    });

    testWidgets(
        'does not call listener when listenWhen returns false on single state '
        'change', (tester) async {
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = <int>[];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (_, __) => false,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'calls listener when listenWhen returns true on single state change',
        (tester) async {
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = [1];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (_, __) => true,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'does not call listener when listenWhen returns false '
        'on multiple state changes', (tester) async {
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = <int>[];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (_, __) => false,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'calls listener when listenWhen returns true on multiple state change',
        (tester) async {
      final states = <int>[];
      final counterNotifier = CounterNotifier();
      const expectedStates = [1, 2, 3, 4];
      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: counterNotifier,
          listenWhen: (_, __) => true,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();
      counterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'updates subscription '
        'when provided notifier is changed', (tester) async {
      final firstCounterNotifier = CounterNotifier();
      final secondCounterNotifier = CounterNotifier(seed: 100);

      final states = <int>[];
      const expectedStates = [1, 101];

      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          listener: (_, state) => states.add(state),
          stateNotifier: firstCounterNotifier,
          child: const SizedBox(),
        ),
      );

      firstCounterNotifier.increment();

      await tester.pumpWidget(
        StateNotifierListener<CounterNotifier, int>(
          stateNotifier: secondCounterNotifier,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );

      secondCounterNotifier.increment();
      await tester.pump();
      firstCounterNotifier.increment();
      await tester.pump();

      expect(states, expectedStates);
    });
  });
}
