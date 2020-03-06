import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:mockito/mockito.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'common.dart';

void main() {
  testWidgets('exposes both controller and value', (tester) async {
    final notifier = TestNotifier(0);

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: Context(),
      ),
    );

    expect(context.read<TestNotifier>(), notifier);
    expect(context.read<int>(), 0);

    expect(notifier.mounted, isTrue);

    await tester.pumpWidget(Container());

    expect(notifier.mounted, isFalse);
  });
  testWidgets('rebuilds dependents', (tester) async {
    final notifier = TestNotifier(0);

    final controller = TextConsumer<TestNotifier>();
    final value = TextConsumer<int>();

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: Column(
          textDirection: TextDirection.ltr,
          children: <Widget>[
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
          children: <Widget>[
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
        child: TextConsumer<int>(),
      ),
    );

    expect(notifier.read<String>(), '42');
    expect(
      () => notifier.read<double>(),
      throwsA(isA<DependencyNotFoundException<double>>()),
    );
  });
  testWidgets("update can't use locator", (tester) async {
    TestNotifier notifier;
    final update = Update((locator) {
      notifier.read<String>();
    });
    notifier = TestNotifier(0, update);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'a'),
          StateNotifierProvider<TestNotifier, int>(
            create: (_) => notifier,
          ),
        ],
        child: TextConsumer<int>(),
      ),
    );

    expect(tester.takeException(), isStateError);
  });
  testWidgets('plugs update', (tester) async {
    String value;
    final update = Update((locator) {
      value = locator<String>();
    });
    final notifier = TestNotifier(0, update);
    final child = TextConsumer<int>();

    final provider = StateNotifierProvider<TestNotifier, int>(
      create: (_) => notifier,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: 'a'),
          provider,
        ],
        child: child,
      ),
    );

    expect(value, 'a');
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

    expect(value, 'b');
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

    expect(value, 'b');
    verifyNoMoreInteractions(update);
  });
  testWidgets('plugs onError', (tester) async {
    final notifier = TestNotifier(0);

    expect(notifier.onError, isNull);

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: TextConsumer<int>(),
      ),
    );

    expect(notifier.onError, isNotNull);
    expect(tester.takeException(), isNull);

    notifier.onError(42, null);
    expect(tester.takeException(), 42);
  });
  testWidgets('rejects StateNotifier with listeners', (tester) async {
    final notifier = TestNotifier(0)..addListener((state) {});

    await tester.pumpWidget(
      StateNotifierProvider<TestNotifier, int>(
        create: (_) => notifier,
        child: TextConsumer<int>(),
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
          children: <Widget>[
            TextConsumer<TestNotifier>(),
            TextConsumer<int>(),
          ],
        ),
      ),
    );

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProvider<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith('(controller: Instance of \'TestNotifier\', value: 0)'));
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
          children: <Widget>[
            TextConsumer<TestNotifier>(),
            TextConsumer<int>(),
          ],
        ),
      ),
    );

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProviderValue<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith('(controller: Instance of \'TestNotifier\', value: 0)'));

    expect(find.text('Instance of \'TestNotifier\''), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    notifier.increment();
    await tester.pump();

    expect(find.text('Instance of \'TestNotifier\''), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    expect(key.currentContext.toString(),
        startsWith('_StateNotifierProviderValue<TestNotifier, int>'));
    expect(key.currentContext.toString(),
        endsWith('(controller: Instance of \'TestNotifier\', value: 1)'));
  });
}
