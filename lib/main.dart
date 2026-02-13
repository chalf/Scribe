import 'package:flutter/material.dart';
import 'screens/notes_list_screen.dart';

void main() {
  runApp(const ScribeApp());
}

class ScribeApp extends StatelessWidget {
  const ScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scribe Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const NotesListScreen(),
    );
  }
}
