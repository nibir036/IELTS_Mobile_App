import 'package:flutter/material.dart';

class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listening')),
      body: const Center(
        child: Text('Listening module placeholder', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
