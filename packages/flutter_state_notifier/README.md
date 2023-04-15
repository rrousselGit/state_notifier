[![pub package](https://img.shields.io/pub/v/flutter_state_notifier.svg)](https://pub.dartlang.org/packages/flutter_state_notifier)

Welcome to **flutter_state_notifier**~

This repository is a side-package that is destined to be used together with **state_notifier**.

It adds extra Flutter bindings to [StateNotifier], such as [provider] integration.

# The available widgets

## [StateNotifierProvider]

[StateNotifierProvider] is the equivalent of [ChangeNotifierProvider] but for
[StateNotifier].

Its job is to both create a [StateNotifier] and dispose it when the provider
is removed from the widget tree.

If the created [StateNotifier] uses [LocatorMixin], [StateNotifierProvider] will
also do the necessary to make `read`/`update` work with [provider].

It is used like most providers, with a small difference:\
Instead of exposing one value, it exposes two values at the same time:

- The [StateNotifier] instance
- The `state` of the [StateNotifier]

Which means that when you write:

```dart
class MyState {}

class MyStateNotifier extends StateNotifier<MyState> {
  MyStateNotifier(): super(MyState());
}

// ...

MultiProvider(
  providers: [
    StateNotifierProvider<MyStateNotifier, MyState>(create: (_) => MyStateNotifier()).
  ]
)
```

This allows you to both:

- obtain the [StateNotifier] in the widget tree, by writing `context.read<MyStateNotifier>()`
- obtain and observe the current [MyState], through `context.watch<MyState>()`

## [StateNotifierBuilder]

[StateNotifierBuilder] is equivalent to `ValueListenableBuilder` from Flutter.

It allows you to listen to a [StateNotifier] and rebuild your UI accordingly, but
does not create/dispose/provide the object.

As opposed to [StateNotifierProvider], this will **not** make `read`/`update` of
[StateNotifier] work.

It is used as such:

```dart
class MyState {}

class MyStateNotifier extends StateNotifier<MyState> {
  MyStateNotifier(): super(MyState());
}

// ...

MyStateNotifier stateNotifier;

return StateNotifierBuilder<MyState>(
  stateNotifier: stateNotifier,
  builder: (BuildContext context, MyState state, Widget child) {
    return Text('$state');
  },
)
```

## [StateNotifierListener]

**StateNotifierListener** is a Flutter widget which takes a [StateNotifierWidgetListener] and an optional `value` and invokes the `listener` in response to state changes in the notifier. It should be used for functionality that needs to occur once per state change such as navigation, showing a `SnackBar`, showing a `Dialog`, etc...

`listener` is only called once for each state change (**NOT** including the initial state) unlike `builder` in [StateNotifierBuilder] and is a `void` function.

If the value parameter is omitted, `StateNotifierListener` will automatically perform a lookup using [StateNotifierProvider] and the current `BuildContext`.

```dart
StateNotifierListener<MyController, MyState>(
  listener: (context, state) {
    // do stuff here based on MyController's state
  },
  child: Container(),
)
```

Only specify the value if you wish to provide a notifier that is otherwise not accessible via [StateNotifierProvider] and the current `BuildContext`.

```dart
StateNotifierListener<MyController, MyState>(
  value: myController,
  listener: (context, state) {
    // do stuff here based on MyController's state
  }
)
```

For fine-grained control over when the `listener` function is called an optional `listenWhen` can be provided. `listenWhen` takes the previous notifier state and current notifier state and returns a boolean. If `listenWhen` returns true, `listener` will be called with `state`. If `listenWhen` returns false, `listener` will not be called with `state`.

```dart
StateNotifierListener<MyController, MyState>(
  listenWhen: (previousState, state) {
    // return true/false to determine whether or not
    // to call listener with state
  },
  listener: (context, state) {
    // do stuff here based on MyController's state
  },
  child: Container(),
)
```

## [MultiStateNotifierListener]

**MultiStateNotifierListener** is a Flutter widget that merges multiple [StateNotifierListener] widgets into one.
[MultiStateNotifierListener] improves the readability and eliminates the need to nest multiple `StateNotifierListeners`.
By using [MultiStateNotifierListener] we can go from:

```dart
StateNotifierListener<MyControllerA, MyStateA>(
  listener: (context, state) {},
  child: StateNotifierListener<MyControllerB, MyStateB>(
    listener: (context, state) {},
    child: StateNotifierListener<MyControllerC, MyStateC>(
      listener: (context, state) {},
      child: MyWidget(),
    ),
  ),
)
```

to:

```dart
MultiStateNotifierListener(
  listeners: [
    StateNotifierListener<MyController, MyStateA>(
      listener: (context, state) {},
    ),
    StateNotifierListener<MyControllerB, MyStateB>(
      listener: (context, state) {},
    ),
    StateNotifierListener<MyControllerC, MyStateC>(
      listener: (context, state) {},
    ),
  ],
  child: MyWidget(),
)
```

[changenotifierprovider]: https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html
[statenotifier]: https://pub.dev/documentation/state_notifier/latest/state_notifier/StateNotifier-class.html
[statenotifierprovider]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierProvider-class.html
[statenotifierbuilder]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierBuilder-class.html
[statenotifierwidgetlistener]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierWidgetListener-class.html
[statenotifierlistener]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierListener-class.html
[multistatenotifierlistener]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/MultiStateNotifierListener-class.html
[locatormixin]: https://pub.dev/documentation/state_notifier/latest/state_notifier/LocatorMixin-class.html
[provider]: https://pub.dev/packages/provider
