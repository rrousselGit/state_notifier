library state_notifier;

import 'dart:collection';

import 'package:meta/meta.dart';

/// A listener that can be added to a [StateNotifier] using
/// [StateNotifier.addListener].
///
/// This callback receives the current [StateNotifier.state] as parameter.
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
typedef ErrorListener = void Function(dynamic error, StackTrace stackTrace);

/// {@macro notifier.locator}
typedef Locator = T Function<T>();

/// An observable class that stores a single immutable [state].
///
/// This class can be considered as a fork of `ValueNotifier` from Flutter, with
/// subtle API changes.
///
/// # Reading the current [state]:
///
/// The [state] property is protected and should be used only by the subclasses
/// of [StateNotifier].\
/// If you want to obtain the current [state] from outside of [StateNotifier],
/// consider using [addListener] instead.
///
/// All listeners added with [addListener] are called **immediatly** on addition
/// with the current [state] as parameter, or whenever [state] changes.
///
/// # The differences with `ValueNotifier`
///
/// [StateNotifier] is not a one to one reimplementation of `ValueNotifier`.
/// It has a few notable differences:
///
/// - it does not depend on Flutter
/// - both the getter and setter of [state] are protected.
/// - adding and removing listeners is O(1) (vs O(N) for `ValueNotifier`)
/// - there is no `notifyListeners` method.
/// - listeners cannot add more listeners.
/// - calling all listeners is O(N) (vs O(N^2) for `ValueNotifier`)
/// - there is no `removeListener` function.
///   Instead, [addListener] returns a function that allows removing the listener.
/// - error reporting is done through [onError].
/// - [StateNotifier] exposes a [mounted] boolean, to know if [dispose] was
///   called or not.
/// - listeners added with [addListener] receives the current [state] as parameter
/// - calling [addListener] immediatly calls the listener with the current [state].
abstract class StateNotifier<T> {
  /// Intiialize [state].
  StateNotifier(this._state);

  final _listeners = LinkedList<_ListenerEntry<T>>();

  /// A callback for error reporting if one of the listeners added with [addListener] throws.
  ///
  /// This callback should not throw.
  ///
  /// It exists merely for error reporting (mainly `FlutterError.onError`), and
  /// should not be used otherwise.\
  /// If you need an error status, consider adding an error property on
  /// your custom [state].
  ErrorListener onError;

  bool _mounted = true;

  /// Wether [dispose] was called or not.
  bool get mounted => _mounted;

  bool _debugCanAddListeners = true;

  bool _debugSetCanAddListeners(bool value) {
    assert(() {
      _debugCanAddListeners = value;
      return true;
    }());
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
    }());
    return true;
  }

  T _state;

  /// The current "state" of this [StateNotifier].
  ///
  /// Updating this variable will synchronously call all the listeners.
  ///
  /// Updating the state will throw if at least one listener throws.
  @protected
  T get state {
    assert(_debugIsMounted());
    return _state;
  }

  /// A developmnent-only way to access [state] outside of [StateNotifier].
  ///
  /// The only difference with [state] is that [debugState] is not "protected".\
  /// Will not work in release mode.
  ///
  /// This is useful for tests.
  T get debugState {
    T result;
    assert(() {
      result = _state;
      return true;
    }());
    return result;
  }

  @protected
  set state(T value) {
    assert(_debugIsMounted());
    _state = value;

    var didThrow = false;
    for (final listenerEntry in _listeners) {
      try {
        listenerEntry.listener(value);
      } catch (err, stack) {
        didThrow = true;
        onError?.call(err, stack);
      }
    }
    if (didThrow) {
      throw Error();
    }
  }

  /// If a listener has been added using [addListener] and hasen't been removed yet.
  bool get hasListeners {
    assert(_debugIsMounted());
    return _listeners.isNotEmpty;
  }

  /// Subscribes to this object.
  ///
  /// The [listener] callback will be called immediatly on addition and
  /// synchronously whenever [state] changes.
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
  /// Adding and removing listeners is O(1).
  RemoveListener addListener(Listener<T> listener) {
    assert(() {
      if (!_debugCanAddListeners) {
        throw ConcurrentModificationError();
      }
      return true;
    }());
    assert(_debugIsMounted());
    final listenerEntry = _ListenerEntry(listener);
    _listeners.add(listenerEntry);
    try {
      assert(_debugSetCanAddListeners(false));
      listener(state);
    } catch (err, stack) {
      listenerEntry.unlink();
      onError?.call(err, stack);
      rethrow;
    } finally {
      assert(_debugSetCanAddListeners(true));
    }

    return () {
      if (listenerEntry.list != null) {
        listenerEntry.unlink();
      }
    };
  }

  /// Frees all the resources associated to this object.
  ///
  /// This marks the object as no longer usable and will make all methods/properties
  /// besides [mounted] inaccessible.
  @mustCallSuper
  void dispose() {
    assert(_debugIsMounted());
    _listeners.clear();
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
/// makes it impossible to shared one instance across multiple "providers".
///
/// See also:
///
/// - [locator], to read objects
/// - [debugMockDependency], to mock dependencies returned by [locator]
/// - [update], a new life-cycle to synchronize this object with external objects.
mixin LocatorMixin {
  // ignore: prefer_function_declarations_over_variables
  Locator _locator = <T>() => throw DependencyNotFoundException<T>();

  /// {@template notifier.locator}
  /// A function that allows obtaining other objects.
  ///
  /// It is typically equivalent to `Provider.of(context, listen: false)` when
  /// using `provider`, but it could also be `GetIt.get` for example.
  /// {@endtemplate}
  ///
  /// **DON'T** modify [locator] manually.\
  /// The only reason why [locator] is not `final` is so that it can be
  /// initialized by providers from `flutter_notifier`.
  @protected
  Locator get locator {
    assert(_debugIsNotifierMounted());
    return _locator;
  }

  set locator(Locator locator) {
    assert(_debugIsNotifierMounted());
    _locator = locator;
  }

  bool _debugIsNotifierMounted() {
    assert(() {
      if (this is StateNotifier) {
        final instance = this as StateNotifier;
        assert(instance._debugIsMounted());
      }
      return true;
    }());
    return true;
  }

  void debugMockDependency<Dependency>(Dependency value) {
    assert(_debugIsNotifierMounted());
    assert(() {
      final previousLocator = locator;
      locator = <Target>() {
        assert(_debugIsNotifierMounted());
        if (Dependency == Target) {
          return value as Target;
        }
        return previousLocator<Target>();
      };
      return true;
    }());
  }

  /// A life-cycle that allows listening to updates on another object.
  ///
  /// This is equivalent to what "ProxyProviders" do using `provider`, but
  /// implemented with no dependency on Flutter.
  @protected
  void update(Locator locator) {}
}

/// Thrown when called [LocatorMixin.locator], but the object was not found.
class DependencyNotFoundException<T> implements Exception {}
