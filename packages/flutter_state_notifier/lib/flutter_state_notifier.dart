library flutter_state_notifier;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// ignore: undefined_hidden_name
import 'package:provider/provider.dart' hide Locator;
import 'package:provider/single_child_widget.dart';
import 'package:state_notifier/state_notifier.dart';

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
