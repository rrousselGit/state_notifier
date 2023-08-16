import 'package:example/my_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  test('increment/decrement update count and log change', () {
    final logger = LoggerMock();
    final myNotifier = MyStateNotifier()..debugMockDependency<Logger>(logger);

    expect(myNotifier.state.count, 0);

    myNotifier.increment();

    expect(myNotifier.state.count, 1000);
    verify(logger.countChanged(1000)).called(1);
    verifyNoMoreInteractions(logger);
  });
}

class LoggerMock extends Mock implements Logger {}
