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
  test(
    'it updates and does not notify when updateShouldNotify return false',
    () {
      final notifier = TestNotifier(0);

      /// initial state
      expect(notifier.currentState, 0);

      /// incrementing the state will always notify
      notifier.increment();
      expect(notifier.currentState, 1);

      /// to check if the update notified or not
      var listenerCalled = false;

      /// since `addListener` immediately calls with the last state
      /// we need to skip the first one
      var firstCall = true;
      notifier.addListener((state) {
        if (firstCall) {
          firstCall = false;
        } else {
          listenerCalled = true;
        }
      });
      notifier.decrement();

      expect(
        notifier.currentState,
        0,
        reason:
            'the state changes even though the updateShouldNotify returned false',
      );
      expect(
        listenerCalled,
        isFalse,
        reason:
            'since `UpdateShouldNotify` returned false, the listener should not be called',
      );
    },
  );
}
