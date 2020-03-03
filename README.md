Welcome to **Notifier**~

This repository is a set of packages that reimplements [ValueNotifier] and
[ChangeNotifier] outside of Flutter.

It is spread across two packages:

- `notifier`, a pure Dart package containing the reimplementation of [ValueNotifier]
  and [ChangeNotifier].
- `flutter_notifier`, a binding between `notifier` and Flutter. It adds things
  like [ChangeNotifierProvider] from [provider], but for these reimplementations

# Motivation

Extracting [ChangeNotifier] and [ValueNotifier] outside of Flutter in a separate
package has two purposes:

- It allows packages Dart packages with no dependency on Flutter to use these
  classes.\
  This means that we can use them on AngularDart for example.
- It allows solving some common problems with the original [ChangeNotifier]/[ValueNotifier]
  and/or their combination with [provider].

For example, by using `notifier` instead of the original [ChangeNotifier]/[ValueNotifier], then
you get:

- A significant simplification of the integration with [provider]
- Simplified testing/mocking
- Improved performances on `addListener` & `notifierListeners` equivalents.

# Usage

## ValueNotifier > StateNotifier

[ValueNotifier] is reimplemented under the name "[StateNotifier]".

[provider]: https://pub.dev/packages/provider
[changenotifierprovider]: https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html
[valuenotifier]: https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html
[changenotifier]: https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html
