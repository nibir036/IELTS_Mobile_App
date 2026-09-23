import 'package:flutter/material.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading')),
      body: const Center(
        child: Text('Reading module placeholder', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
