import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MemoPingApp());
}

class MemoPingApp extends StatelessWidget {
  const MemoPingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모핑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

