import 'package:example/my_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:provider/provider.dart';

// This is the default counter example reimplemented using StateNotifier + provider
// It will also print in the console the counter whenever it changes

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
        ),
      ],
      child: MyApp(),
    ),
  );
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
  const MyHomePage({Key key}) : super(key: key);

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
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: context.watch<MyStateNotifier>().increment,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
