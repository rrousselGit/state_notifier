[![pub package](https://img.shields.io/pub/v/state_notifier.svg)](https://pub.dartlang.org/packages/state_notifier)
Welcome to **state_notifier**~

This package is a recommended solution for managing state when using [Provider] or [Riverpod].

Long story short, instead of extending [ChangeNotifier], extend [StateNotifier]:

```dart
class City {
  City({required this.name, required this.population});
  final String name;
  final int population;
}


class CityNotifier extends StateNotifier<List<City>> {
  CityNotifier() : super(const <City>[]);

  void addCity(City newCity) {
    state = [
      ...state,
      newCity,
    ];
  }
}
```

## Motivation

The purpose of [StateNotifier] is to be a simple solution to control state in
an immutable manner.  
While [ChangeNotifier] is simple, through its mutable nature, it can be harder to
maintain as it grows larger.

By using immutable state, it becomes a lot simpler to:

- compare previous and new state
- implement an undo-redo mechanism
- debug the application state

## Good practices

### **DON'T** update the state of a StateNotifier outside the notifier

While you could technically write:

```dart
class Counter extends StateNotifier<int> {
  Counter(): super(0);
}

final notifier = Counter();
notifier.state++;
```

That is considered an anti-pattern (and your IDE should show a warning).

Only the [StateNotifier] should modify its state. Instead, prefer using a method:

```dart
class Counter extends StateNotifier<int> {
  Counter(): super(0);

  void increment() => state++:
}

final notifier = Counter();
notifier.increment();
```

The goal is to centralize all the logic that modifies a [StateNotifier] within
the [StateNotifier] itself.

## FAQ

### Why are listeners called when the new state is == to the previous state?

You may realize that a [StateNotifier] does not use `==` to verify that
the state has changed before notifying for changes.

This behavior is voluntary, for performance reasons.

The reasoning is that `StateNotifier` is typically used with complex objects,
which often override `==` to perform a deep comparison.  
But performing a deep comparison can be a costly operation, especially since
it is common for the state to contain lists/maps.  
Similarly, for complex states, it is rare that when calling `notifier.state = newState`,
the new and previous states are the same.

As such, instead of using `==`, [StateNotifier] relies on `identical` to compare
objects.  
This way, when using [StateNotifier] with simple states like `int`/enums, it will
correctly filter identical states. At the same time, this preserves performance
on complex states, as `identical` will not perform a deep object comparison.

### Using custom notification filter logic

You can override the method `updateShouldNotify(T old,T current)` of a `StateNotifier` to change the default behaviour, such as for:
- using `==` instead of `identical` to filter updates, for deep state comparison
- always returning `true` to revert to older behaviors of `StateNotifier`

```dart
  @override
  bool updateShouldNotify(User old, User current) {
    /// only update the User content changes, even if using a different instance
    return old.name != current.name && old.age != current.age;
  }
```

## Usage

### Integration with Freezed

While entirely optional, it is recommended to use [StateNotifier] in combination
with [Freezed].  
[Freezed] is a code-generation package for data-classes in Dart, which
automatically generates methods like `copyWith` and adds support for union-types.

A typical example would be using [Freezed] to handle data vs error vs loading states.
With its union-types, it can lead to a significant improvement in maintainability as
it:

- ensures that your application will not enter illogical states
  (such as both having a "data" and being in the "loading" state)
- ensures that logic handles all possible cases. Such as forcing that the
  loading/error cases be checked before trying to access the data.

The idea is that, rather than defining the data, error and loading state in a single
object like:

```dart
class MyState {
  MyState(...);
  final Data data;
  final Object? error;
  final bool loading;
}
```

We can use Freezed to define it as:

```dart
@freezed
class MyState {
  factory MyState.data(Data data) = MyStateData;
  factory MyState.error(Object? error) = MyStateError;
  factory MyState.loading() = MyStateLoading;
}
```

That voluntarily prevents us from doing:

```dart
void main() {
  MyState state;
  print(state.data);
}
```

Instead, we can use the generated `map` method to handle the various cases:

```dart
void main() {
  MyState state;
  state.when(
    data: (state) => print(state.data),
    loading: (state) => print('loading'),
    error: (state) => print('Error: ${state.error}'),
  );
}
```

### Integration with [provider]/service locators

[StateNotifier] is easily compatible with [provider] through an extra mixin: `LocatorMixin`.

Consider a typical [StateNotifier]:

```dart
class Count {
  Count(this.count);
  final int count;
}

class Counter extends StateNotifier<Count> {
  Counter(): super(Count(0));

  void increment() {
    state = Count(state.count + 1);
  }
}
```

In this example, we may want to use `Provider.of`/`context.read` to connect our
`Counter` with external services.

To do so, simply mix-in `LocatorMixin` as such:

```dart
class Counter extends StateNotifier<Count> with LocatorMixin {
// unchanged
}
```

That then gives you access to:

- `read`, a function to obtain services
- `update`, a new life-cycle that can be used to listen to changes on a service

We could use them to change our `Counter` incrementation to save the counter in
a DB when incrementing the value:

```dart
class Counter extends StateNotifier<Count> with LocatorMixin {
  Counter(): super(Count(0))

  void increment() {
    state = Count(state.count + 1);
    read<LocalStorage>().writeInt('count', state.count);
  }
}
```

Where `Counter` and `LocalStorage` are defined using `provider` this way:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => LocalStorage()),
        StateNotifierProvider<Counter, Count>(create: (_) => Counter()),
      ],
      child: MyApp(),
    ),
  );
}
```

Then, `Counter`/`Count` are consumed using your typical `context.watch`/`Consumer`/`context.select`/...:

```dart
@override
Widget build(BuildContext context) {
  int count = context.watch<Count>().count;

  return Scaffold(
    body: Text('$count'),
    floatingActionButton: FloatingActionButton(
      onPressed: () => context.read<Counter>().increment(),
      child: Icon(Icons.add),
    ),
  );
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

**Note:** `LocatorMixin` only works on `StateNotifier`. If you try to use it on other classes by using `with LocatorMixin`, it will not work.

[provider]: https://pub.dev/packages/provider
[freezed]: https://pub.dev/packages/freezed
[riverpod]: https://pub.dev/packages/riverpod
[changenotifierprovider]: https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html
[statenotifier]: https://pub.dev/documentation/state_notifier/latest/state_notifier/StateNotifier-class.html
[locatormixin]: https://pub.dev/documentation/state_notifier/latest/state_notifier/LocatorMixin-class.html
[valuenotifier]: https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html
[changenotifier]: https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html
