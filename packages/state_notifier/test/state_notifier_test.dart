import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:state_notifier/state_notifier.dart';

Matcher throwsDependencyNotFound<T>() {
  return throwsA(isA<DependencyNotFoundException<T>>());
}

void main() {
  test('initialize state with default value', () {
    expect(TestNotifier(0).currentState, 0);
    expect(TestNotifier(42).currentState, 42);
    expect(TestNotifier(0).debugState, 0);
    expect(TestNotifier(42).debugState, 42);
  });
  test('setter modifies the value', () {
    final notifier = TestNotifier(0);

    expect(notifier.currentState, 0);
    expect(notifier.debugState, 0);
    notifier.increment();
    expect(notifier.currentState, 1);
    expect(notifier.debugState, 1);
    notifier.increment();
    expect(notifier.currentState, 2);
    expect(notifier.debugState, 2);
  });
  test('listener called immediatly on addition + synchronously on value change',
      () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    notifier.addListener(listener);

    verify(listener(0)).called(1);
    verifyNoMoreInteractions(listener);

    notifier.increment();

    verify(listener(1)).called(1);
    verifyNoMoreInteractions(listener);
  });
  test(
      'listener not called immediately on addition if fireImmediately is false',
      () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    notifier.addListener(listener, fireImmediately: false);

    verifyNever(listener(0));
    verifyNoMoreInteractions(listener);

    notifier.increment();

    verify(listener(1)).called(1);
    verifyNoMoreInteractions(listener);
  });
  test('listener is called after the value is updated', () {
    final notifier = TestNotifier(0);

    int lastValue;
    notifier
      ..addListener((value) => lastValue = value)
      ..increment();

    expect(lastValue, 1);
  });
  test('allowTransition is called with correct values', () {
    final allowTransition = AllowTransition();
    when(allowTransition.call(any, any)).thenReturn(true);

    final notifier = AllowTransitionTestNotifier(0)
      ..transition = allowTransition
      ..increment();
    verify(allowTransition(0, 1)).called(1);

    notifier.increment();
    verify(allowTransition(1, 2)).called(1);
  });
  test('allowTransition can return false to prevent state update', () {
    var allow = false;

    final notifier = AllowTransitionTestNotifier(0)
      ..transition = (_, __) => allow;

    // ignore: cascade_invocations
    notifier.increment();
    expect(notifier.debugState, 0);

    allow = true;
    notifier.increment();
    expect(notifier.debugState, 1);

    allow = false;
    notifier.increment();
    expect(notifier.debugState, 1);
  });
  test('listener can be removed using addListener result', () {
    final notifier = TestNotifier(0);
    final listener = Listener();
    final listener2 = Listener();

    final removeListener = notifier.addListener(listener);
    final removeListener2 = notifier.addListener(listener2);

    verify(listener(0)).called(1);
    verify(listener2(0)).called(1);

    notifier.increment();

    verifyInOrder([
      listener(1),
      listener2(1),
    ]);
    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);

    removeListener();

    notifier.increment();

    verify(listener2(2)).called(1);

    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);

    removeListener2();

    notifier.increment();

    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);
  });

  test('removeListener can be called multiple times without effect', () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    final removeListener = notifier.addListener(listener);
    // adding the same listener twice
    final removeListener2 = notifier.addListener(listener);

    verify(listener(0)).called(2);

    notifier.increment();

    verify(listener(1)).called(2);
    verifyNoMoreInteractions(listener);

    removeListener();

    notifier.increment();

    verify(listener(2)).called(1);
    verifyNoMoreInteractions(listener);

    removeListener();
    notifier.increment();

    verify(listener(3)).called(1);
    verifyNoMoreInteractions(listener);

    removeListener2();

    notifier.increment();

    verifyNoMoreInteractions(listener);
  });

  test('hasListeners', () {
    final notifier = TestNotifier(0);

    expect(notifier.hasListeners, isFalse);

    final removeListener = notifier.addListener((value) {
      expect(notifier.hasListeners, isTrue);
    });
    expect(notifier.hasListeners, isTrue);
    final removeListener2 = notifier.addListener((value) {
      expect(notifier.hasListeners, isTrue);
    });
    expect(notifier.hasListeners, isTrue);

    removeListener();

    expect(notifier.hasListeners, isTrue);

    removeListener2();
    expect(notifier.hasListeners, isFalse);
  });
  test('dispose', () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    final removeListener = notifier.addListener(listener);
    clearInteractions(listener);

    notifier.dispose();

    expect(() => notifier.currentState, throwsStateError);
    expect(notifier.increment, throwsStateError);
    expect(() => notifier.hasListeners, throwsStateError);
    expect(() => notifier.read, throwsStateError);
    expect(() => notifier.debugMockDependency(42), throwsStateError);
    expect(() => notifier.read = <T>() => throw Error(), throwsStateError);

    verifyZeroInteractions(listener);

    expect(notifier.dispose, throwsStateError);

    removeListener();
  });
  test('mounted', () {
    final notifier = TestNotifier(0);

    expect(notifier.mounted, isTrue);

    notifier.dispose();

    expect(notifier.mounted, isFalse);
  });
  test('addListener immediatly throws does not add the listener', () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    when(listener(0)).thenThrow(42);

    expect(() => notifier.addListener(listener), throwsA(42));
    verify(listener(0)).called(1);
    verifyNoMoreInteractions(listener);

    notifier.increment();

    verifyNoMoreInteractions(listener);
  });
  test('onError (initial)', () {
    final onError = ErrorListener();
    final notifier = TestNotifier(0)..onError = onError;

    verifyZeroInteractions(onError);

    final error = Error();
    expect(
      () => notifier.addListener((state) {
        throw error;
      }),
      throwsA(error),
    );

    verify(onError(error, argThat(isNotNull))).called(1);
    verifyNoMoreInteractions(onError);
  });
  test('onError (change)', () {
    final onError = ErrorListener();
    final notifier = TestNotifier(0)
      ..onError = onError
      ..addListener((v) {
        if (v > 0) throw StateError('message');
      })
      ..addListener((v) {
        if (v > 0) throw ArgumentError();
      });

    verifyZeroInteractions(onError);

    expect(notifier.increment, throwsA(isA<Error>()));

    verifyInOrder([
      onError(argThat(isA<StateError>()), argThat(isNotNull)),
      onError(argThat(isA<ArgumentError>()), argThat(isNotNull)),
    ]);
    verifyNoMoreInteractions(onError);
  });
  test('listeners cannot add listeners (intiial call)', () {
    final notifier = TestNotifier(0);

    expect(
      () => notifier.addListener((state) {
        notifier.addListener((state) {});
      }),
      throwsConcurrentModificationError,
    );

    final listener = Listener();

    notifier.addListener(listener);

    verify(listener(0)).called(1);
    verifyNoMoreInteractions(listener);

    notifier.increment();

    verify(listener(1)).called(1);
    verifyNoMoreInteractions(listener);
  });
  test('listeners cannot add listeners (update)', () {
    final notifier = TestNotifier(0);

    notifier.addListener((state) {
      if (state == 1) {
        notifier.addListener((state) {});
      }
    });

    expect(notifier.increment, throwsConcurrentModificationError);

    final listener = Listener();

    notifier.addListener(listener);

    verify(listener(1)).called(1);
    verifyNoMoreInteractions(listener);

    notifier.increment();

    verify(listener(2)).called(1);
    verifyNoMoreInteractions(listener);
  });
  test('read throws by default', () {
    expect(
      () => TestNotifier(0).read<int>(),
      throwsDependencyNotFound<int>(),
    );
  });
  test('debugUpdate calls initState+update and disables read', () {
    final notifier = TestNotifier(0)..debugMockDependency('42');

    expect(notifier.lastInitString, null);
    expect(notifier.lastUpdateString, null);
    expect(notifier.lastUpdateRead, null);

    notifier.debugUpdate();

    expect(notifier.lastInitString, '42');
    expect(notifier.lastUpdateString, '42');
    expect(notifier.lastUpdateRead, throwsStateError);

    notifier
      ..debugMockDependency('24')
      ..debugUpdate();

    expect(notifier.lastInitString, '42');
    expect(notifier.lastUpdateString, '24');
    expect(notifier.lastUpdateRead, throwsStateError);
  });
  group('debugMockDependency', () {
    test('can mock dependencies', () {
      final notifier = TestNotifier(0);

      expect(
        () => notifier.read<int>(),
        throwsDependencyNotFound<int>(),
      );

      notifier.debugMockDependency<int>(42);

      expect(notifier.read<int>(), 42);
      expect(() => notifier.read<String>(), throwsDependencyNotFound<String>());
    });
    test('mock is using identical type comparison -> no subclass', () {
      final notifier = TestNotifier(0)..debugMockDependency<num>(42);

      expect(notifier.read<num>(), 42);
      expect(() => notifier.read<int>(), throwsDependencyNotFound<int>());
      expect(() => notifier.read<double>(), throwsDependencyNotFound<double>());
    });
    test('mocking dependency then disposing the objet correctly disable read',
        () {
      final notifier = TestNotifier(0)
        ..debugMockDependency(42)
        ..dispose();

      expect(() => notifier.read, throwsStateError);
    });
  });
}

class TestNotifier extends StateNotifier<int> with LocatorMixin {
  TestNotifier(int state) : super(state);

  int get currentState => state;

  void increment() {
    state++;
  }

  String lastInitString;

  @override
  void initState() {
    lastInitString = read<String>();
  }

  @override
  void update(Locator watch) {
    lastUpdateRead = read;
    lastUpdateString = watch<String>();
  }

  Locator lastUpdateRead;
  String lastUpdateString;

  @override
  // ignore: unnecessary_overrides, remove protected
  Locator get read => super.read;
}

class Listener extends Mock {
  void call(int value);
}

class ErrorListener extends Mock {
  void call(dynamic error, StackTrace stackTrace);
}

class AllowTransitionTestNotifier extends TestNotifier {
  AllowTransitionTestNotifier(int state) : super(state);

  bool Function(int, int) transition;

  @override
  bool allowTransition(int fromState, int toState) =>
      transition(fromState, toState);
}

class AllowTransition extends Mock {
  bool call(int from, int to);
}
