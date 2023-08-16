library state_notifier;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

/// A listener that can be added to a [StateNotifier] using
/// [StateNotifier.addListener].
///
/// This callback receives the current [StateNotifier.state] as a parameter.
typedef Listener<T> = void Function(T state);

/// A callback that can be used to remove a listener added with
/// [StateNotifier.addListener].
///
/// It is safe to call this callback multiple times.
///
/// Calling this callback multiple times will remove the listener only once,
/// even if [StateNotifier.addListener] was called multiple times with the exact
/// same listener.
typedef RemoveListener = void Function();

/// A callback that can be passed to [StateNotifier.onError].
///
/// This callback should not throw.
///
/// It exists merely for error reporting (mainly `FlutterError.onError`), and
/// should not be used otherwise.\
/// If you need an error status, consider adding an error property on
/// your custom [StateNotifier.state].
typedef ErrorListener = void Function(Object error, StackTrace? stackTrace);

/// A function that allows obtaining other objects.
///
/// This is usually equivalent to `Provider.of`, but with no dependency on Flutter
///
/// May throw a [DependencyNotFoundException].
typedef Locator = T Function<T>();

/// An error thrown when trying to update the state of a [StateNotifier],
/// but at least one of the listeners threw.
@sealed
class StateNotifierListenerError extends Error {
  StateNotifierListenerError._(
    this.errors,
    this.stackTraces,
    this.stateNotifier,
  ) : assert(
          errors.length == stackTraces.length,
          'errors and stackTraces must match',
        );

  /// A map of all the errors and their stacktraces thrown by listeners.
  final List<Object> errors;

  /// The stacktraces associated with [errors].
  final List<StackTrace?> stackTraces;

  /// The [StateNotifier] that failed to update its state.
  final StateNotifier<Object?> stateNotifier;

  @override
  String toString() {
    final buffer = StringBuffer();

    for (var i = 0; i < errors.length; i++) {
      final error = errors[i];
      final stackTrace = stackTraces[i];

      buffer
        ..writeln(error)
        ..writeln(stackTrace);
    }

    return '''
At least listener of the StateNotifier $stateNotifier threw an exception
when the notifier tried to update its state.

The exceptions thrown are:

$buffer
''';
  }
}

/// An observable class that stores a single immutable [state].
///
/// It can be used as a drop-in replacement to `ChangeNotifier` or other equivalent
/// objects like `Bloc`.
/// Its particularity is that it tries to be simple, yet promote immutable data.
///
/// By using immutable state, it becomes a lot simpler to:
/// - compare previous and new state
/// - implement an undo-redo mechanism
/// - debug the application state
/// ## Example: Counter
///
/// [StateNotifier] is designed to be subclassed.
/// We first need to pass an initial value to the `super` constructor, to define
/// the initial state of our object.
///
/// ```dart
/// class Counter extends StateNotifier<int> {
///   Counter(): super(0);
/// }
/// ```
///
/// We can then expose methods on our [StateNotifier] to allow other objects
/// to modify the counter:
///
/// ```dart
/// class Counter extends StateNotifier<int> {
///   Counter(): super(0);
///
///   void increment() => state++;
///   void decrement() => state--;
/// }
/// ```
///
/// assigning [state] to a new value will automatically notify the listeners
/// and update the UI.
///
/// Then, the object can be listened to with `StateNotifierBuilder`/`StateNotifierProvider`
/// using `package:flutter_state_notifier` or `package:riverpod`.
///
/// See also:
///
/// - [addListener], to manually listen to a [StateNotifier]
/// - [state], to internally read and update the value exposed.
abstract class StateNotifier<T> {
  /// Initialize [state].
  StateNotifier(this._state);

  final _listeners = LinkedList<_ListenerEntry<T>>();

  /// A callback for error reporting if one of the listeners added with [addListener] throws.
  ///
  /// This callback should not throw.
  ///
  /// It exists for error reporting (mainly `FlutterError.onError`), and
  /// should not be used otherwise.\
  /// If you need an error status, consider adding an error property on
  /// your custom [state].
  ///
  /// If no [onError] is specified, fallbacks to [Zone.current.handleUncaughtError].
  ErrorListener? onError;

  bool _mounted = true;

  /// Whether [dispose] was called or not.
  bool get mounted => _mounted;

  StreamController<T>? _controller;

  /// A broadcast stream representation of a [StateNotifier].
  Stream<T> get stream {
    _controller ??= StreamController<T>.broadcast();
    return _controller!.stream;
  }

  bool _debugCanAddListeners = true;

  bool _debugSetCanAddListeners(bool value) {
    assert(() {
      _debugCanAddListeners = value;
      return true;
    }(), '');
    return true;
  }

  bool _debugIsMounted() {
    assert(() {
      if (!_mounted) {
        throw StateError('''
Tried to use $runtimeType after `dispose` was called.

Consider checking `mounted`.
''');
      }
      return true;
    }(), '');
    return true;
  }

  T _state;

  /// The current "state" of this [StateNotifier].
  ///
  /// Updating this variable will synchronously call all the listeners.
  /// Notifying the listeners is O(N) with N the number of listeners.
  ///
  /// Updating the state will throw if at least one listener throws.
  @protected
  @visibleForTesting
  T get state {
    assert(_debugIsMounted(), '');
    return _state;
  }

  /// Whether to notify listeners or not when [state] changes
  @protected
  bool updateShouldNotify(
    T old,
    T current,
  ) =>
      !identical(old, current);

  @protected
  @visibleForTesting
  set state(T value) {
    assert(_debugIsMounted(), '');
    final previousState = _state;
    _state = value;

    /// only notify listeners when should
    if (!updateShouldNotify(previousState, value)) {
      return;
    }

    _controller?.add(value);

    final errors = <Object>[];
    final stackTraces = <StackTrace?>[];
    for (final listenerEntry in _listeners) {
      try {
        listenerEntry.listener(value);
      } catch (error, stackTrace) {
        errors.add(error);
        stackTraces.add(stackTrace);

        if (onError != null) {
          onError!(error, stackTrace);
        } else {
          Zone.current.handleUncaughtError(error, stackTrace);
        }
      }
    }
    if (errors.isNotEmpty) {
      throw StateNotifierListenerError._(errors, stackTraces, this);
    }
  }

  /// A development-only way to access [state] outside of [StateNotifier].
  ///
  /// The only difference with [state] is that [debugState] is not "protected".\
  /// Will not work in release mode.
  ///
  /// This is useful for tests.
  @Deprecated('Use state instead')
  T get debugState {
    late T result;
    assert(() {
      result = _state;
      return true;
    }(), '');
    return result;
  }

  /// If a listener has been added using [addListener] and hasn't been removed yet.
  bool get hasListeners {
    assert(_debugIsMounted(), '');
    return _listeners.isNotEmpty;
  }

  /// Subscribes to this object.
  ///
  /// The [listener] callback will be called immediately on addition and
  /// synchronously whenever [state] changes.
  /// Set [fireImmediately] to false if you want to skip the first,
  /// immediate execution of the [listener].
  ///
  /// To remove this [listener], call the function returned by [addListener]:
  ///
  /// ```dart
  /// StateNotifier<Model> example;
  /// final removeListener = example.addListener((value) => ...);
  /// removeListener();
  /// ```
  ///
  /// Listeners cannot add other listeners.
  ///
  /// Adding and removing listeners has a constant time-complexity.
  RemoveListener addListener(
    Listener<T> listener, {
    bool fireImmediately = true,
  }) {
    assert(() {
      if (!_debugCanAddListeners) {
        throw ConcurrentModificationError();
      }
      return true;
    }(), '');
    assert(_debugIsMounted(), '');
    final listenerEntry = _ListenerEntry(listener);
    _listeners.add(listenerEntry);
    try {
      assert(_debugSetCanAddListeners(false), '');
      if (fireImmediately) {
        listener(state);
      }
    } catch (err, stack) {
      listenerEntry.unlink();
      onError?.call(err, stack);
      rethrow;
    } finally {
      assert(_debugSetCanAddListeners(true), '');
    }

    return () {
      if (listenerEntry.list != null) {
        listenerEntry.unlink();
      }
    };
  }

  /// Frees all the resources associated with this object.
  ///
  /// This marks the object as no longer usable and will make all methods/properties
  /// besides [mounted] inaccessible.
  @mustCallSuper
  void dispose() {
    assert(_debugIsMounted(), '');
    _listeners.clear();
    _controller?.close();
    _mounted = false;
  }
}

class _ListenerEntry<T> extends LinkedListEntry<_ListenerEntry<T>> {
  _ListenerEntry(this.listener);

  final Listener<T> listener;
}

/// A mixin that adds service location capability to an object.
///
/// This makes the object aware of things like `Provider.of` or `GetIt`, without
/// actually depending on those.\
/// It also provides testing utilities to be able to mock dependencies.
///
/// In the context of Flutter + `provider`, adding that mixin to an object
/// makes it impossible to share one instance across multiple "providers".
///
/// This mix-in does not do anything by itself.\
/// It is simply an interface for 3rd party libraries such as provider to implement
/// the logic.
///
/// See also:
///
/// - [read], to read objects
/// - [debugMockDependency], to mock dependencies returned by [read]
/// - [update], a new life-cycle to synchronize this object with external objects.
/// - [debugUpdate], a method to test [update].
mixin LocatorMixin {
  // ignore: prefer_function_declarations_over_variables
  Locator _locator = <T>() => throw DependencyNotFoundException<T>();

  /// A function that allows obtaining other objects.
  ///
  /// It is typically equivalent to `Provider.of(context, listen: false)` when
  /// using `provider`, but it could also be `GetIt.get` for example.
  ///
  /// **DON'T** modify [read] manually.\
  /// The only reason why [read] is not `final` is so that it can be
  /// initialized by providers from `flutter_notifier`.
  ///
  /// May throw a [DependencyNotFoundException] if the looked-up type is not found.
  @protected
  Locator get read {
    assert(_debugIsNotifierMounted(), '');
    return _locator;
  }

  set read(Locator read) {
    assert(_debugIsNotifierMounted(), '');
    _locator = read;
  }

  bool _debugIsNotifierMounted() {
    assert(() {
      if (this is StateNotifier) {
        final instance = this as StateNotifier;
        assert(instance._debugIsMounted(), '');
      }
      return true;
    }(), '');
    return true;
  }

  /// Overrides [read] to mock its behavior in development.
  ///
  /// This does nothing in release mode and is useful only for test purpose.
  ///
  /// A typical usage would be:
  ///
  /// ```dart
  /// class MyServiceMock extends Mock implements MyService {}
  ///
  /// test('mock dependency', () {
  ///   final myStateNotifier = MyStateNotifier();
  ///   myStateNotifier.debugMockDependency<MyService>(MyServiceMock());
  /// });
  /// ```
  void debugMockDependency<Dependency>(Dependency value) {
    assert(_debugIsNotifierMounted(), '');
    assert(() {
      final previousLocator = read;
      read = <Target>() {
        assert(_debugIsNotifierMounted(), '');
        if (Dependency == Target) {
          return value as Target;
        }
        return previousLocator<Target>();
      };
      return true;
    }(), '');
  }

  /// A life-cycle that allows initializing the [StateNotifier] based on values
  /// coming from [read].
  ///
  /// This method will be called once, right before [update].
  ///
  /// It is useful as constructors cannot access [read].
  @protected
  void initState() {}

  /// A life-cycle that allows listening to updates on another object.
  ///
  /// This is equivalent to what "ProxyProviders" do using `provider`, but
  /// implemented with no dependency on Flutter.
  ///
  /// The property [read] is not accessible while inside the body of [update].
  /// Use the parameter passed to [update] instead, which will not just read the
  /// object but also watch for changes.
  @protected
  void update(Locator watch) {}

  var _debugDidInitState = false;

  /// A test utility to test the behavior of your [initState]/[update] method.
  ///
  /// The first time [debugUpdate] is called, this will call [initState] + [update].
  /// Further calls will only call [update].
  ///
  /// While inside [update], [read] will be disabled as it would be in production.
  void debugUpdate() {
    assert(() {
      if (!_debugDidInitState) {
        _debugDidInitState = true;
        initState();
      }

      final locator = read;
      read = <T>() => throw StateError('Cannot use `read` inside `update`');
      try {
        update(locator);
      } finally {
        read = locator;
      }
      return true;
    }(), '');
  }
}

/// Thrown when tried to call [LocatorMixin.read<T>()], but the [T] was not found.s
class DependencyNotFoundException<T> implements Exception {}
