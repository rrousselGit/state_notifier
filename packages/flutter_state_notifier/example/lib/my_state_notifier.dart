import 'package:meta/meta.dart';
import 'package:state_notifier/state_notifier.dart';

// A Counter example using StateNotifier
// It also uses an external Logger class to log any state change.

// Note that this file does not depend on Flutter and could very well be extracted
// in a different package

abstract class Logger {
  void countChanged(int count);
}

class MyState {
  MyState(this.count);
  final int count;
}

class MyStateNotifier extends StateNotifier<MyState> with LocatorMixin {
  MyStateNotifier() : super(MyState(0));

  void increment() {
    state = MyState(state.count + 1000);
  }

  @override
  @protected
  set state(MyState value) {
    if (state.count != value.count) {
      read<Logger>().countChanged(value.count);
    }
    super.state = value;
  }
}

/// A simple [Logger] using [print]
class ConsoleLogger implements Logger {
  @override
  void countChanged(int count) {
    // ignore: avoid_print
    print('Count changed $count');
  }
}
