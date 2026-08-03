import 'package:flutter/material.dart';

void main() {
  runApp(const FocusQuestApp());
}

class FocusQuestApp extends StatelessWidget {
  const FocusQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FocusQuest')),
      body: const Center(
        child: Text('Focus timer quests coming soon'),
      ),
    );
  }
}
