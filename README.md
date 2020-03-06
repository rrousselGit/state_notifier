Welcome to **state_notifier**~

This repository is a set of packages that reimplements [ValueNotifier] outside of Flutter.

It is spread across two packages:

- `notifier`, a pure Dart package containing the reimplementation of [ValueNotifier].\
  It comes with extra utilities for combining our "[ValueNotifier]" with [provider]
  and to test it.
- `flutter_notifier`, a binding between `notifier` and Flutter.\
  It adds things like [ChangeNotifierProvider] from [provider], but compatible
  with `notifier`.

# Motivation

Extracting [ValueNotifier] outside of Flutter in a separate
package has two purposes:

- It allows packages Dart packages with no dependency on Flutter to use these
  classes.\
  This means that we can use them on AngularDart for example.
- It allows solving some common problems with the original [ChangeNotifier]/[ValueNotifier]
  and/or their combination with [provider].

For example, by using `notifier` instead of the original [ValueNotifier], then
you get:

- A significant simplification of the integration with [provider]
- Simplified testing/mocking
- Improved performances on `addListener` & `notifyListeners` equivalents.
- Extra safety through small API changes

# Integration with [provider]/service locators

[StateNotifier] is easily compatible with [provider] through an extra mixin: `LocatorMixin`.

Consider a typical [StateNotifier] written like a [ValueNotifier]:

```dart
class Counter extends StateNotifier<int> {
  Counter(): super(0)

  void increment() {
    state++;
  }
}
```

In this example, we may want to use `Provider.of`/`context.read` to connect our
`Counter` with external services.

To do so, simply mix-in `LocatorMixin` as such:

```dart
class Counter extends StateNotifier<int> with LocatorMixin {
// unchanged
}
```

This then gives you access to:

- `locator`, a function to obtain services
- `update`, a new life-cycle that can be used to listen to changes on a service

We could use them to change our `Counter` incrementation to save the counter in
a DB when incrementing the value:

```dart
class Counter extends StateNotifier<int> {
  Counter(): super(0)

  void increment() {
    state++;
    locator<LocalStorage>().writeInt('count', state);
  }
}
```

**Testing**

When using `LocatorMixin`, you may want to mock a dependency for your tests.\
Of course, we still don't want to depend on Flutter/provider to do such a thing.

Similarly, since `state` is protected, tests need a simple way to read the state.

As such, `LocatorMixin` also adds extra utilities to help you with this scenario:

```dart
myStateNotifier.debugMockDependency<MyDependency>(myDependency);
print(myStateNotifier.debugState);
myStateNotifier.debugUpdate();
```

As such, if we want to test our previous `Counter`, we could mock `LocalStorage`
this way:

```dart
test('increment and saves to local storage', () {
  final mockLocalStorage = MockLocalStorage();
  final counter = Counter()
    ..debugMockDependency<LocalStorage>(mockLocalStorage);

  expect(counter.debugState, 0);

  counter.increment(); // works fine since we mocked the LocalStorage

  expect(counter.debugState, 1);
  // mockito stuff
  verify(mockLocalStorage.writeInt('int', 1));
});
```

# Differences with [ValueNotifier]

This is not a one-to-one reimplementation of [ValueNotifier]. It has some
differences:

- [ValueNotifier] is instead named [StateNotifier] (to avoid name clash)
- `ValueNotifier.value` is renamed to `state`, to match the class name
- [StateNotifier] is abstract
- `state` is `@protected`
- The listener passed to `addListener` receives the current `state`, and is called
  synchronously on addition.
- `addListener` and `removeListener` are fused in a single `addListener` function
  which returns a function to remove the listener.\
  This makes adding and removing listeners O(1) versus O(N) for [ValueNotifier].
- listeners cannot add extra listeners.\
  This makes notifying listeners O(N) versus O(N²) for [ValueNotifier]
- offers a `mounted` boolean to know if the [StateNotifier] was disposed or not,
  similar to `State`.

[provider]: https://pub.dev/packages/provider
[changenotifierprovider]: https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html
[statenotifier]: https://pub.dev/documentation/state_notifier/latest/state_notifier/StateNotifier-class.html
[LocatorMixin]: https://pub.dev/documentation/state_notifier/latest/state_notifier/LocatorMixin-class.html
[valuenotifier]: https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html
[changenotifier]: https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html
