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

[changenotifierprovider]: https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html
[statenotifier]: https://pub.dev/documentation/state_notifier/latest/state_notifier/StateNotifier-class.html
[statenotifierprovider]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierProvider-class.html
[statenotifierbuilder]: https://pub.dev/documentation/flutter_state_notifier/latest/flutter_state_notifier/StateNotifierBuilder-class.html
[LocatorMixin]: https://pub.dev/documentation/state_notifier/latest/state_notifier/LocatorMixin-class.html
[provider]: https://pub.dev/packages/provider
