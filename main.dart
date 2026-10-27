import 'package:flutter/material.dart';

import 'reminders.dart';
import 'store.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Reminders.init();
  } catch (_) {}
  final store = NoteStore();
  await store.load();
  runApp(StickyMemoApp(store: store));
}

class StickyMemoApp extends StatelessWidget {
  const StickyMemoApp({super.key, required this.store});

  final NoteStore store;

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B56C9), brightness: b),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: store.theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'Sticky Memo',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomePage(store: store),
      ),
    );
  }
}
