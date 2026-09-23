import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = ['Reading', 'Writing', 'Listening', 'Speaking'];
    return Scaffold(
      appBar: AppBar(title: const Text('NextEd IELTS')),
      body: ListView(
        children: modules
            .map((m) => ListTile(
          title: Text(m),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/${m.toLowerCase()}'),
        ))
            .toList(),
      ),
    );
  }
}