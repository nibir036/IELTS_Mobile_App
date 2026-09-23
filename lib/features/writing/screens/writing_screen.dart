import 'package:flutter/material.dart';

class WritingScreen extends StatelessWidget {
  const WritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Writing')),
      body: const Center(
        child: Text('Writing module placeholder', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
