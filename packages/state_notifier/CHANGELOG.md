## 1.0.0 - 2023-08-16

- `state` is now accessible in tests without a warning.
- `debugState` is removed Use `state` instead.

## 0.7.2+1

- Fixed an issue with `updateShouldNotify` naturally always returning `false`.

## 0.7.2

- Added `StateNotifier.updateShouldNotify` for customizing notification filtering (thanks to @maxzod)

## 0.7.1

- Improved the error when a listener of a `StateNotifier` throws to include
  the thrown error/stacktrace
- `StateNotifier.state =` now filters updates using `identical`.

## 0.7.0

Stable release of null-safe `StateNotifier`

## 0.7.0-nullsafety.0

Migrated to non-nullable types

## [0.6.0] - 28/07/2020

Added `StateNotifier.stream`, to listen to a `StateNotifier` using the `Stream` API.

## [0.5.0] - 4/06/2020

If no `onError` is specified, errors are now reported to the current `Zone`.

## [0.4.0] - 13/03/2020

Added a flag on `addListener` to disable the first immediate call of the listener
thanks to @smiLLe

## [0.3.0] - 08/03/2020

Add an `initState` life-cycle to be able to init the `StateNotifier` using `read`.

## [0.1.0+1] - 06/03/2020

Add example

## [0.1.0] - 06/03/2020

Initial release.
