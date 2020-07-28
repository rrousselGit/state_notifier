import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart' hide Locator;
import 'package:state_notifier/state_notifier.dart';

class TestNotifier extends StateNotifier<int> with LocatorMixin {
  TestNotifier(int state, {this.onInitState, this.onUpdate}) : super(state);

  int get currentState => state;

  void increment() {
    state++;
  }

  final void Function() onInitState;
  final void Function(Locator watch) onUpdate;

  @override
  // ignore: unnecessary_overrides, remvove protected
  Locator get read => super.read;

  @override
  void initState() {
    onInitState?.call();
  }

  @override
  void update(T Function<T>() watch) {
    onUpdate?.call(watch);
  }
}

class Listener extends Mock {
  void call(int value);
}

class Update extends Mock {
  Update([void Function(Locator watch) cb]) {
    if (cb != null) {
      when(call(any)).thenAnswer((realInvocation) {
        final locator = realInvocation.positionalArguments.first as Locator;
        return cb(locator);
      });
    }
  }
  void call(Locator watch);
}

class InitState extends Mock {
  InitState([void Function() cb]) {
    if (cb != null) {
      when(call()).thenAnswer((realInvocation) {
        return cb();
      });
    }
  }
  void call();
}

class ErrorListener extends Mock {
  void call(dynamic error, StackTrace stackTrace);
}

BuildContext get context => find.byType(Context).evaluate().single;

class Context extends StatelessWidget {
  const Context({Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

int buildCountOf<T extends TextConsumer<dynamic>>(T value) {
  final element = find.byWidget(value).evaluate().single as StatefulElement;
  return (element.state as _TextConsumerState).buildCount;
}

class TextConsumer<T> extends StatefulWidget {
  const TextConsumer({Key key}) : super(key: key);
  @override
  _TextConsumerState<T> createState() => _TextConsumerState<T>();
}

class _TextConsumerState<T> extends State<TextConsumer<T>> {
  int buildCount = 0;
  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Text(
      Provider.of<T>(context).toString(),
      textDirection: TextDirection.ltr,
    );
  }
}
