import 'package:state_notifier/state_notifier.dart';
import 'package:test/test.dart';

class TestNotifier extends StateNotifier<int> {
  TestNotifier(int state) : super(state);

  int get currentState => state;

  void increment() => state++;

  void decrement() => state--;

  @override
  bool updateShouldNotify(int old, int current) {
    /// only update if the new state is greeter than the old state
    return current > old;
  }
}

void main() {
  test('it does not update if the updateShouldNotify returned false', () {
    final notifier = TestNotifier(0);

    expect(notifier.currentState, 0);
    notifier.increment();

    expect(notifier.currentState, 1);

    notifier.decrement();

    /// still have the old state
    expect(
      notifier.currentState,
      1,
      reason: 'updateShouldNotify returned false',
    );
  });
}
