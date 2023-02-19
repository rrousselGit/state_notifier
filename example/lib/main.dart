import 'package:example/my_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:provider/provider.dart';

// This is the default counter example reimplemented using StateNotifier + provider
// It will print in the console the counter whenever it changes
// The state change is also animated.

// The "print to console" feature is abstracted through a "Logger" class like
// we would do in production.

// This showcase how our custom MyStateNotifier does not depend on Flutter,
// but is still able to read providers and be used as usual in a Flutter app.

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<Logger>(create: (_) => ConsoleLogger()),
        StateNotifierProvider<MyStateNotifier, MyState>(
          create: (_) => MyStateNotifier(),
          // Override MyState to make it animated
          builder: (context, child) {
            return TweenAnimationBuilder<MyState>(
              duration: const Duration(milliseconds: 500),
              tween: MyStateTween(end: context.watch<MyState>()),
              builder: (context, state, _) {
                return Provider.value(value: state, child: child);
              },
            );
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}

/// A [MyStateTween].
///
/// This will apply an [IntTween] on [MyState.count].
class MyStateTween extends Tween<MyState> {
  MyStateTween({MyState? begin, MyState? end}) : super(begin: begin, end: end);

  @override
  MyState lerp(double t) {
    final countTween = IntTween(begin: begin?.count, end: end?.count);
    // Tween the count
    return MyState(
      countTween.lerp(t),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              context.select((MyState value) => value.count).toString(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: context.watch<MyStateNotifier>().increment,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
