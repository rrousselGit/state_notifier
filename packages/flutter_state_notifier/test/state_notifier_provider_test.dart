import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:state_notifier/state_notifier.dart';

import 'common.dart';

void main() {
  testWidgets('StateNotifierProvider builder', (tester) async {
    final notifier = TestNotifier(0);

    final expectedChild = Container();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        builder: (context, child) {
          assert(child == expectedChild, '');
          return Text(
            Provider.of<int>(context).toString(),
            textDirection: TextDirection.ltr,
          );
        },
        child: expectedChild,
      ),
    );

    expect(find.text('0'), findsOneWidget);
  });
  testWidgets('StateNotifierProvider.value builder', (tester) async {
    final notifier = TestNotifier(0);

    final expectedChild = Container();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>.value(
        value: notifier,
        builder: (context, child) {
          assert(child == expectedChild, '');
          return Text(
            Provider.of<int>(context).toString(),
            textDirection: TextDirection.ltr,
          );
        },
        child: expectedChild,
      ),
    );

    expect(find.text('0'), findsOneWidget);
  });
  testWidgets('exposes both controller and value', (tester) async {
    final notifier = TestNotifier(0);

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: const Context(),
      ),
    );

    expect(Provider.of<TestNotifier>(context, listen: false), notifier);
    expect(Provider.of<int>(context, listen: false), 0);

    expect(notifier.mounted, isTrue);

    await tester.pumpWidget(Container());

    expect(notifier.mounted, isFalse);
  });
  testWidgets('rebuilds dependents', (tester) async {
    final notifier = TestNotifier(0);

    const controller = TextConsumer<TestNotifier>();
    const value = TextConsumer<int>();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: Column(
          textDirection: TextDirection.ltr,
          children: const <Widget>[
            controller,
            value,
          ],
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(buildCountOf(controller), 1);
    expect(buildCountOf(value), 1);

    notifier.increment();

    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(buildCountOf(controller), 1);
    expect(buildCountOf(value), 2);

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: Column(
          textDirection: TextDirection.ltr,
          children: const <Widget>[
            controller,
            value,
          ],
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(buildCountOf(controller), 1);
    expect(buildCountOf(value), 2);
  });
  testWidgets('plugs locator', (tester) async {
    final notifier = TestNotifier(0);

    expect(
      () => notifier.read<String>(),
      throwsA(isA<DependencyNotFoundException<String>>()),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => '42'),
          StateNotifierProvider<TestNotifier, int>(create: (_) => notifier),
        ],
        child: const TextConsumer<int>(),
      ),
    );

    expect(notifier.read<String>(), '42');
    expect(
      () => notifier.read<double>(),
      throwsA(isA<DependencyNotFoundException<double>>()),
    );
  });
  testWidgets("update can't use locator", (tester) async {
    late TestNotifier notifier;
    final update = Update((locator) {
      notifier.read<String>();
    });
    notifier = TestNotifier(0, onUpdate: update);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'a'),
          StateNotifierProvider<TestNotifier, int>(
            create: (_) => notifier,
          ),
        ],
        child: const TextConsumer<int>(),
      ),
    );

    expect(tester.takeException(), isStateError);
  });
  testWidgets('plugs update', (tester) async {
    late TestNotifier notifier;
    String? initValue;
    final initState = InitState(() {
      initValue = notifier.read<String>();
    });
    String? updateValue;
    final update = Update((watch) {
      updateValue = watch<String>();
    });
    notifier = TestNotifier(0, onUpdate: update, onInitState: initState);

    final provider = StateNotifierProvider<TestNotifier, int>(
      create: (_) => notifier,
    );

    verifyZeroInteractions(initState);
    verifyZeroInteractions(update);

    const child = TextConsumer<int>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'a'),
          provider,
        ],
        child: child,
      ),
    );

    verify(initState()).called(1);
    expect(initValue, 'a');
    verifyNoMoreInteractions(initState);
    expect(updateValue, 'a');
    verify(update(argThat(isNotNull))).called(1);
    verifyNoMoreInteractions(update);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'b'),
          provider,
        ],
        child: child,
      ),
    );

    expect(updateValue, 'b');
    verify(update(argThat(isNotNull))).called(1);
    verifyNoMoreInteractions(update);
    verifyNoMoreInteractions(initState);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'b'),
          provider,
        ],
        child: child,
      ),
    );

    expect(updateValue, 'b');
    verifyNoMoreInteractions(update);
    verifyNoMoreInteractions(initState);
  });
  testWidgets('plugs onError', (tester) async {
    final notifier = TestNotifier(0);

    expect(notifier.onError, isNull);

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: const TextConsumer<int>(),
      ),
    );

    expect(notifier.onError, isNotNull);
    expect(tester.takeException(), isNull);

    notifier.onError!(42, null);
    expect(tester.takeException(), 42);
  });
  testWidgets('rejects StateNotifier with listeners', (tester) async {
    final notifier = TestNotifier(0)..addListener((state) {});

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: const TextConsumer<int>(),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });
  testWidgets('toString', (tester) async {
    final notifier = TestNotifier(0);
    final key = GlobalKey();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        key: key,
        create: (_) => notifier,
        child: Column(
          textDirection: TextDirection.ltr,
          children: const <Widget>[
            TextConsumer<TestNotifier>(),
            TextConsumer<int>(),
          ],
        ),
      ),
    );

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProvider<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith("(controller: Instance of 'TestNotifier', value: 0)"));
  });

  testWidgets('.value', (tester) async {
    final notifier = TestNotifier(0);
    final key = GlobalKey();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>.value(
        key: key,
        value: notifier,
        child: Column(
          textDirection: TextDirection.ltr,
          children: const <Widget>[
            TextConsumer<TestNotifier>(),
            TextConsumer<int>(),
          ],
        ),
      ),
    );

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProviderValue<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith("(controller: Instance of 'TestNotifier', value: 0)"));

    expect(find.text("Instance of 'TestNotifier'"), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    notifier.increment();
    await tester.pump();

    expect(find.text("Instance of 'TestNotifier'"), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProviderValue<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith("(controller: Instance of 'TestNotifier', value: 1)"));
  });

  testWidgets('works', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          StateNotifierProvider<_Controller1, Counter1>(
            create: (context) => _Controller1(),
          ),
          StateNotifierProvider<_Controller2, Counter2>(
            create: (context) => _Controller2(),
          ),
        ],
        child: Consumer<Counter2>(
          builder: (c, value, _) {
            return Text('${value.count}', textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
  });
}

class _Controller1 extends StateNotifier<Counter1> {
  _Controller1() : super(Counter1(0));

  void increment() => state = Counter1(state.count + 1);
}

class Counter1 {
  Counter1(this.count);

  final int count;
}

class _Controller2 extends StateNotifier<Counter2> with LocatorMixin {
  _Controller2() : super(Counter2(0));

  void increment() => state = Counter2(state.count + 1);

  @override
  void update(T Function<T>() watch) {
    watch<Counter1>();
    watch<_Controller1>();
  }
}

class Counter2 {
  Counter2(this.count);

  final int count;
}
