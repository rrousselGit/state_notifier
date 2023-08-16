import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:test/test.dart';

Matcher throwsDependencyNotFound<T>() {
  return throwsA(isA<DependencyNotFoundException<T>>());
}

Matcher throwsStateNotifierListenerError({
  List<Object>? errors,
  List<Object>? stackTraces,
  Object? notifier,
}) {
  var matcher = isA<StateNotifierListenerError>();

  if (errors != null) {
    matcher = matcher.having((e) => e.errors, 'errors', errors);
  }
  if (stackTraces != null) {
    matcher = matcher.having((e) => e.stackTraces, 'stackTraces', stackTraces);
  }
  if (notifier != null) {
    matcher = matcher.having((e) => e.stateNotifier, 'notifier', notifier);
  }

  return throwsA(matcher);
}

void main() {
  test('initialize state with default value', () {
    expect(TestNotifier(0).state, 0);
    expect(TestNotifier(42).state, 42);
  });

  test('setter modifies the value', () {
    final notifier = TestNotifier(0);

    expect(notifier.state, 0);

    notifier.increment();
    expect(notifier.state, 1);

    notifier.increment();
    expect(notifier.state, 2);
  });

  test('can set state', () {
    final notifier = TestNotifier(0);
    expectLater(notifier.stream, emitsInOrder([1, 2]));
    notifier.state = 1;
    expect(notifier.state, 1);
    notifier.state = 2;
    expect(notifier.state, 2);
    notifier.state = 2;
    expect(notifier.state, 2);
    notifier.dispose();
  });

  test(
      'listener called immediately on addition + synchronously on value change',
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

    int? lastValue;
    notifier
      ..addListener((value) => lastValue = value)
      ..increment();

    expect(lastValue, 1);
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

    expect(() => notifier.state, throwsStateError);
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

  test('addListener immediately throws does not add the listener', () {
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
      () => notifier.addListener((state) => throw error),
      throwsA(error),
    );

    verify(onError(error, argThat(isNotNull))).called(1);
    verifyNoMoreInteractions(onError);
  });

  test('no onError fallbacks to zone', () {
    final notifier = TestNotifier(0)
      ..addListener((v) {
        if (v > 0) {
          throw StateError('first');
        }
      })
      ..addListener((v) {
        if (v > 0) {
          throw StateError('second');
        }
      });

    final errors = <Object>[];
    runZonedGuarded(notifier.increment, (err, stack) => errors.add(err));

    expect(errors, [
      isStateError.having((s) => s.message, 'message', 'first'),
      isStateError.having((s) => s.message, 'message', 'second'),
      isA<Error>(),
    ]);
  });

  test('onError (change)', () {
    final onError = ErrorListener();
    final notifier = TestNotifier(0)
      ..onError = onError
      ..addListener((v) {
        if (v > 0) {
          throw StateError('message');
        }
      })
      ..addListener((v) {
        if (v > 0) {
          throw ArgumentError();
        }
      });

    verifyZeroInteractions(onError);

    expect(
      notifier.increment,
      throwsStateNotifierListenerError(
        errors: [isStateError, isArgumentError],
        stackTraces: [anything, anything],
        notifier: notifier,
      ),
    );

    verifyInOrder([
      onError(argThat(isA<StateError>()), argThat(isNotNull)),
      onError(argThat(isA<ArgumentError>()), argThat(isNotNull)),
    ]);
    verifyNoMoreInteractions(onError);
  });

  test('filters state update on identical state', () {
    final notifier = TestNotifier(0);
    final listener = Listener();

    notifier.addListener(listener, fireImmediately: true);

    verify(listener(0)).called(1);
    verifyNoMoreInteractions(listener);

    notifier.setState(0);

    verifyNoMoreInteractions(listener);
  });

  test('listeners cannot add listeners (initial call)', () {
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
    test('mocking dependency then disposing the object correctly disable read',
        () {
      final notifier = TestNotifier(0)
        ..debugMockDependency(42)
        ..dispose();

      expect(() => notifier.read, throwsStateError);
    });
  });

  test(
      '.stream returns a broadcast stream that updates when new values are pushed',
      () async {
    final notifier = TestNotifier(0);
    final stream = notifier.stream;

    // ignore: unawaited_futures
    Future.microtask(() {
      notifier
        ..increment()
        ..increment()
        ..increment();
    });

    await expectLater(stream, emitsInOrder(<int>[1, 2, 3]));

    notifier.dispose();

    await expectLater(stream, emitsDone);
  });
}

class TestNotifier extends StateNotifier<int> with LocatorMixin {
  TestNotifier(int state) : super(state);

  void increment() => state++;

  // ignore: use_setters_to_change_properties
  void setState(int value) {
    state = value;
  }

  String? lastInitString;

  @override
  void initState() {
    lastInitString = read<String>();
  }

  @override
  void update(Locator watch) {
    lastUpdateRead = read;
    lastUpdateString = watch<String>();
  }

  Locator? lastUpdateRead;
  String? lastUpdateString;

  @override
  // ignore: unnecessary_overrides, remove protected
  Locator get read => super.read;
}

class Listener extends Mock {
  void call(int value);
}

class ErrorListener extends Mock {
  void call(Object? error, StackTrace? stackTrace);
}
