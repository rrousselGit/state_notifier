## 1.0.0 - 2023-08-16

- `state` is now accessible in tests without a warning.
- `debugState` is removed Use `state` instead.

## 0.7.3

The package now re-exports `package:state_notifier`

## 0.7.1

- Update dependencies
- Improved the error when a listener of a `StateNotifier` throws to include
  the thrown error/stacktrace
- `StateNotifier.state =` now filters updates using `identical`.

## 0.7.0

Migrated to null-safety.

## 0.6.1

Fixed a conflict between provider and state_notifier

## 0.6.0

Added `StateNotifier.stream`, to listen to a `StateNotifier` using the `Stream` API.

## 0.4.2

- Fix the `builder` parameter of `StateNotifierProvider` not working

## 0.4.1

- Add support for provider 4.0.x

## 0.4.0

- Add an optional `builder` parameter on `StateNotifierProvider`

## 0.3.0

- Add support for `LocatorMixin.initState` on `StateNotifierProvider`

## 0.2.0

- Added `.value` constructor on `StateNotifierProvider`

## 0.1.0+1

- Add example

## 0.1.0

- initial release.
