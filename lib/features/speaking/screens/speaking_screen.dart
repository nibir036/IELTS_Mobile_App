import 'package:flutter/material.dart';

class SpeakingScreen extends StatelessWidget {
  const SpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speaking')),
      body: const Center(
        child: Text('Speaking module placeholder', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
