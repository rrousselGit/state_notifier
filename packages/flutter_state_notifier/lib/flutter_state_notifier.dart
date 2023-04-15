library flutter_state_notifier;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// ignore: undefined_hidden_name
import 'package:provider/provider.dart' hide Locator;
import 'package:provider/single_child_widget.dart';
import 'package:state_notifier/state_notifier.dart';

export 'package:state_notifier/state_notifier.dart' hide Listener, Locator;

/// {@template flutter_state_notifier.state_notifier_builder}
/// Listens to a [StateNotifier] and use it builds a widget tree based on the
/// latest value.
///
/// This is similar to [ValueListenableBuilder] for [ValueNotifier].
/// {@endtemplate}
class StateNotifierBuilder<T> extends StatefulWidget {
  /// {@macro flutter_state_notifier.state_notifier_builder}
  const StateNotifierBuilder({
    Key? key,
    required this.builder,
    required this.stateNotifier,
    this.child,
  }) : super(key: key);

  /// A callback that builds a [Widget] based on the current value of [stateNotifier]
  ///
  /// Cannot be `null`.
  final ValueWidgetBuilder<T> builder;

  /// The listened to [StateNotifier].
  ///
  /// Cannot be `null`.
  final StateNotifier<T> stateNotifier;

  /// A cache of a subtree that does not depend on [stateNotifier].
  ///
  /// It will be sent untouched to [builder]. This is useful for performance
  /// optimizations to not rebuild the entire widget tree if it isn't needed.
  final Widget? child;

  @override
  _StateNotifierBuilderState<T> createState() =>
      _StateNotifierBuilderState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<StateNotifier<T>>('stateNotifier', stateNotifier),
      )
      ..add(DiagnosticsProperty<Widget>('child', child))
      ..add(ObjectFlagProperty<ValueWidgetBuilder<T>>.has('builder', builder));
  }
}

class _StateNotifierBuilderState<T> extends State<StateNotifierBuilder<T>> {
  late T state;
  VoidCallback? removeListener;

  @override
  void initState() {
    super.initState();
    _listen(widget.stateNotifier);
  }

  @override
  void didUpdateWidget(StateNotifierBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stateNotifier != oldWidget.stateNotifier) {
      _listen(widget.stateNotifier);
    }
  }

  void _listen(StateNotifier<T> notifier) {
    removeListener?.call();
    removeListener = notifier.addListener(_listener);
  }

  void _listener(T value) {
    setState(() => state = value);
  }

  @override
  void dispose() {
    removeListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, state, widget.child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('state', state));
  }
}

// Don't uses a closure to not capture local variables.
Locator _contextToLocator(BuildContext context) {
  return <T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException catch (_) {
      throw DependencyNotFoundException<T>();
    }
  };
}

/// A provider for [StateNotifier], which exposes both the controller and its
/// [StateNotifier.state].
///
/// It can be used like most providers.
///
/// Consider the following [StateNotifier]:
/// ```dart
/// class MyController extends StateNotifier<MyValue> {
/// ...
/// }
/// ```
///
/// Then we can expose it to a Flutter app by doing:
///
/// ```dart
/// MultiProvider(
///   providers: [
///     StateNotifierProvider<MyController, MyValue>(create: (_) => MyController()),
///   ],
/// )
/// ```
///
/// This will allow both:
///
/// - `context.watch<MyController>()`
/// - `context.watch<MyValue>()`
///
/// Note that watching `MyController` will not cause the listener to rebuild when
/// [StateNotifier.state] updates.
abstract class StateNotifierProvider<Controller extends StateNotifier<Value>,
        Value>
    implements
        // ignore: avoid_implementing_value_types
        SingleChildStatelessWidget {
  /// Creates a [StateNotifier] instance and exposes both the [StateNotifier]
  /// and its [StateNotifier.state] using `provider`.
  ///
  /// **DON'T** use this with an existing [StateNotifier] instance, as removing
  /// the provider from the widget tree will dispose the [StateNotifier].\
  /// Instead consider using [StateNotifierBuilder].
  ///
  /// `create` cannot be `null`.
  factory StateNotifierProvider({
    Key? key,
    required Create<Controller> create,
    bool? lazy,
    TransitionBuilder? builder,
    Widget? child,
  }) = _StateNotifierProvider<Controller, Value>;

  /// Exposes an existing [StateNotifier] and its [value].
  ///
  /// This will not call [StateNotifier.dispose] when the provider is removed
  /// from the widget tree.
  ///
  /// It will also not setup [LocatorMixin].
  ///
  /// `value` cannot be `null`.
  factory StateNotifierProvider.value({
    Key? key,
    required Controller value,
    TransitionBuilder? builder,
    Widget? child,
  }) = _StateNotifierProviderValue<Controller, Value>;
}

class _StateNotifierProviderValue<Controller extends StateNotifier<Value>,
        Value> extends SingleChildStatelessWidget
    implements StateNotifierProvider<Controller, Value> {
  // ignore: prefer_const_constructors_in_immutables
  _StateNotifierProviderValue({
    Key? key,
    required this.value,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Controller value;
  final TransitionBuilder? builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider.value(
      value: value,
      child: StateNotifierBuilder<Value>(
        stateNotifier: value,
        builder: (c, state, _) {
          return Provider.value(
            value: state,
            child: builder != null //
                ? Builder(builder: (c) => builder!(c, child))
                : child,
          );
        },
      ),
    );
  }

  @override
  SingleChildStatelessElement createElement() {
    return _StateNotifierProviderElement(this);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('controller', value));
  }
}

class _StateNotifierProvider<Controller extends StateNotifier<Value>, Value>
    extends SingleChildStatelessWidget
    implements StateNotifierProvider<Controller, Value> {
  // ignore: prefer_const_constructors_in_immutables
  _StateNotifierProvider({
    Key? key,
    required this.create,
    this.lazy,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Create<Controller> create;
  final bool? lazy;
  final TransitionBuilder? builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider<Controller>(
      create: (context) {
        final result = create(context);
        assert(
          result.onError == null,
          'StateNotifierProvider created a StateNotifier that was already passed'
          ' to another StateNotifierProvider',
        );
        // ignore: avoid_types_on_closure_parameters
        result.onError = (Object error, StackTrace? stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'flutter_state_notifier',
          ));
        };
        if (result is LocatorMixin) {
          (result as LocatorMixin)
            ..read = _contextToLocator(context)
            // ignore: invalid_use_of_protected_member
            ..initState();
        }
        return result;
      },
      debugCheckInvalidValueType: kReleaseMode
          ? null
          : (value) {
              assert(
                !value.hasListeners,
                'StateNotifierProvider created a StateNotifier that is already'
                ' being listened to by something else',
              );
            },
      update: (context, controller) {
        if (controller is LocatorMixin) {
          // ignore: cast_nullable_to_non_nullable
          final locatorMixin = controller as LocatorMixin;
          late Locator debugPreviousLocator;
          assert(() {
            // ignore: invalid_use_of_protected_member
            debugPreviousLocator = locatorMixin.read;
            locatorMixin.read = <T>() {
              throw StateError("Can't use `read` inside the body of `update");
            };
            return true;
          }(), '');
          // ignore: invalid_use_of_protected_member
          locatorMixin.update(<T>() => Provider.of<T>(context));
          assert(() {
            locatorMixin.read = debugPreviousLocator;
            return true;
          }(), '');
        }
        return controller!;
      },
      dispose: (_, controller) => controller.dispose(),
      child: DeferredInheritedProvider<Controller, Value>(
        lazy: lazy,
        create: (context) {
          return Provider.of<Controller>(context, listen: false);
        },
        startListening: (context, setState, controller, _) {
          return controller.addListener(setState);
        },
        child: builder != null //
            ? Builder(builder: (c) => builder!(c, child))
            : child,
      ),
    );
  }

  @override
  SingleChildStatelessElement createElement() {
    return _StateNotifierProviderElement(this);
  }
}

class _StateNotifierProviderElement<Controller extends StateNotifier<Value>,
    Value> extends SingleChildStatelessElement {
  _StateNotifierProviderElement(StateNotifierProvider<Controller, Value> widget)
      : super(widget);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    late Element provider;

    void visitor(Element e) {
      if (e.widget is InheritedProvider<Value>) {
        provider = e;
      } else {
        e.visitChildren(visitor);
      }
    }

    visitChildren(visitor);

    provider.debugFillProperties(properties);
  }
}

/// Signature for the `listener` function which takes the `BuildContext` along
/// with the `state` and is responsible for executing in response to
/// `state` changes.
typedef StateNotifierWidgetListener<Value> = void Function(
    BuildContext context, Value state);

/// Signature for the `listenWhen` function which takes the previous `state`
/// and the current `state` and is responsible for returning a [bool] which
/// determines whether or not to call [StateNotifierWidgetListener] of [StateNotifierListener]
/// with the current `state`.
typedef StateNotifierListenerCondition<Value> = bool Function(
    Value previous, Value current);

/// {@template state_notifier_listener}
/// Takes a [StateNotifierWidgetListener] and an optional [value] and invokes
/// the [listener] in response to `state` changes in the [value].
/// It should be used for functionality that needs to occur only in response to
/// a `state` change such as navigation, showing a `SnackBar`, showing
/// a `Dialog`, etc...
/// The [listener] is guaranteed to only be called once for each `state` change
/// unlike the `builder` in [StateNotifierBuilder].
///
/// If the [value] parameter is omitted, [StateNotifierListener] will automatically
/// perform a lookup using [StateNotifierProvider] and the current `BuildContext`.
///
/// ```dart
/// StateNotifierListener<MyController, MyState>(
///   listener: (context, state) {
///     // do stuff here based on MyController's state
///   },
///   child: Container(),
/// )
/// ```
/// Only specify the [value] if you wish to provide a [value] that is otherwise
/// not accessible via [StateNotifierProvider] and the current `BuildContext`.
///
/// ```dart
/// StateNotifierListener<MyController, MyState>(
///   value: myController,
///   listener: (context, state) {
///     // do stuff here based on MyController's state
///   },
///   child: Container(),
/// )
/// ```
/// {@endtemplate}
///
/// {@template state_notifier_listener_listen_when}
/// An optional [listenWhen] can be implemented for more granular control
/// over when [listener] is called.
/// [listenWhen] will be invoked on each [value] `state` change.
/// [listenWhen] takes the previous `state` and current `state` and must
/// return a [bool] which determines whether or not the [listener] function
/// will be invoked.
/// The previous `state` will be initialized to the `state` of the [value]
/// when the [StateNotifierListener] is initialized.
/// [listenWhen] is optional and if omitted, it will default to `true`.
///
/// ```dart
/// StateNotifierListener<MyController, MyState>(
///   listenWhen: (previous, current) {
///     // return true/false to determine whether or not
///     // to invoke listener with state
///   },
///   listener: (context, state) {
///     // do stuff here based on MyController's state
///   }
///   child: Container(),
/// )
/// ```
/// {@endtemplate}
class StateNotifierListener<Controller extends StateNotifier<Value>, Value>
    extends StateNotifierListenerBase<Controller, Value> {
  /// {@macro state_notifier_listener}
  /// {@macro state_notifier_listener_listen_when}
  const StateNotifierListener({
    Key? key,
    required StateNotifierWidgetListener<Value> listener,
    Controller? value,
    StateNotifierListenerCondition<Value>? listenWhen,
    Widget? child,
  }) : super(
          key: key,
          child: child,
          listener: listener,
          value: value,
          listenWhen: listenWhen,
        );
}

/// {@template state_notifier_listener_base}
/// Base class for widgets that listen to state changes in a specified [value].
///
/// A [StateNotifierListenerBase] is stateful and maintains the state subscription.
/// The type of the state and what happens with each state change
/// is defined by sub-classes.
/// {@endtemplate}
abstract class StateNotifierListenerBase<
    Controller extends StateNotifier<Value>,
    Value> extends SingleChildStatefulWidget {
  /// {@macro state_notifier_listener_base}
  const StateNotifierListenerBase({
    Key? key,
    required this.listener,
    this.value,
    this.child,
    this.listenWhen,
  }) : super(key: key, child: child);

  /// The widget which will be rendered as a descendant of the
  /// [StateNotifierListenerBase].
  final Widget? child;

  /// The [value] whose `state` will be listened to.
  /// Whenever the [value]'s `state` changes, [listener] will be invoked.
  final Controller? value;

  /// The [StateNotifierWidgetListener] which will be called on every `state` change.
  /// This [listener] should be used for any code which needs to execute
  /// in response to a `state` change.
  final StateNotifierWidgetListener<Value> listener;

  /// {@macro state_notifier_listener_listen_when}
  final StateNotifierListenerCondition<Value>? listenWhen;

  @override
  SingleChildState<StateNotifierListenerBase<Controller, Value>>
      createState() => _StateNotifierListenerBaseState<Controller, Value>();
}

class _StateNotifierListenerBaseState<Controller extends StateNotifier<Value>,
        Value>
    extends SingleChildState<StateNotifierListenerBase<Controller, Value>> {
  StreamSubscription<Value>? _subscription;
  late Controller _controller;
  late Value _previousState;

  @override
  void initState() {
    super.initState();
    _controller = widget.value ?? context.read<Controller>();
    // ignore: invalid_use_of_protected_member
    _previousState = _controller.state;
    _subscribe();
  }

  @override
  void didUpdateWidget(StateNotifierListenerBase<Controller, Value> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.value ?? context.read<Controller>();
    final currentController = widget.value ?? oldController;
    if (oldController != currentController) {
      if (_subscription != null) {
        _unsubscribe();
        _controller = currentController;
        // ignore: invalid_use_of_protected_member
        _previousState = _controller.state;
      }
      _subscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = widget.value ?? context.read<Controller>();
    if (_controller != controller) {
      if (_subscription != null) {
        _unsubscribe();
        _controller = controller;
        // ignore: invalid_use_of_protected_member
        _previousState = _controller.state;
      }
      _subscribe();
    }
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      child != null,
      '''${widget.runtimeType} used outside of MultiStateNotifierListener must specify a child''',
    );
    if (widget.value == null) {
      // Trigger a rebuild if the controller reference has changed.
      context.select<Controller, bool>(
          (controller) => identical(_controller, controller));
    }
    return child!;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _subscription = _controller.stream.listen((state) {
      if (widget.listenWhen?.call(_previousState, state) ?? true) {
        widget.listener(context, state);
      }
      _previousState = state;
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// {@template multi_state_notifier_listener}
/// Merges multiple [StateNotifierListener] widgets into one widget tree.
///
/// [MultiStateNotifierListener] improves the readability and eliminates the need
/// to nest multiple [StateNotifierListener]s.
///
/// By using [MultiStateNotifierListener] we can go from:
///
/// ```dart
/// StateNotifierListener<MyControllerA, MyStateA>(
///   listener: (context, state) {},
///   child: StateNotifierListener<MyControllerB, MyStateB>(
///     listener: (context, state) {},
///     child: StateNotifierListener<MyControllerC, MyStateC>(
///       listener: (context, state) {},
///       child: MyWidget(),
///     ),
///   ),
/// )
/// ```
///
/// to:
///
/// ```dart
/// MultiStateNotifierListener(
///   listeners: [
///     StateNotifierListener<MyControllerA, MyStateA>(
///       listener: (context, state) {},
///     ),
///     StateNotifierListener<MyControllerB, MyStateB>(
///       listener: (context, state) {},
///     ),
///     StateNotifierListener<MyControllerC, MyStateC>(
///       listener: (context, state) {},
///     ),
///   ],
///   child: MyWidget(),
/// )
/// ```
///
/// [MultiStateNotifierListener] converts the [StateNotifierListener] list into a tree of nested
/// [StateNotifierListener] widgets.
/// As a result, the only advantage of using [MultiStateNotifierListener] is improved
/// readability due to the reduction in nesting and boilerplate.
/// {@endtemplate}
class MultiStateNotifierListener extends MultiProvider {
  /// {@macro multi_state_notifier_listener}
  MultiStateNotifierListener({
    Key? key,
    required List<SingleChildWidget> listeners,
    required Widget child,
  }) : super(key: key, providers: listeners, child: child);
}
