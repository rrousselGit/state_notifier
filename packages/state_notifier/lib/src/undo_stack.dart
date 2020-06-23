import 'dart:collection';

class ChangeStack<T> {
  final Queue<Change<T>> _history = ListQueue();
  final Queue<Change<T>> _redos = ListQueue();

  int max;

  bool get canRedo => _redos.isNotEmpty;
  bool get canUndo => _history.isNotEmpty;

  /// Undo/Redo History
  ChangeStack({this.max});

  /// Add New Change and Clear Redo Stack
  void add(Change<T> change) {
    change.execute();

    _history.addLast(change);
    _redos.clear();

    if (max != null && _history.length > max) {
      _history.removeFirst();
    }
  }

  /// Clear Undo History
  void clear() {
    _history.clear();
    _redos.clear();
  }

  /// Redo Previous Undo
  void redo() {
    if (canRedo) {
      final change = _redos.removeFirst()..execute();
      _history.addLast(change);
    }
  }

  /// Undo Last Change
  void undo() {
    if (canUndo) {
      final change = _history.removeLast()..undo();
      _redos.addFirst(change);
    }
  }
}

class Change<T> {
  final T _oldValue;
  final Function _execute;
  final Function(T oldValue) _undo;

  Change(
    this._oldValue,
    this._execute(),
    this._undo(T oldValue),
  );

  void execute() {
    _execute();
  }

  void undo() {
    _undo(_oldValue);
  }
}
