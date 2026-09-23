import 'package:flutter/material.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const NextEdIeltsApp());
}

class NextEdIeltsApp extends StatelessWidget {
  const NextEdIeltsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NextEd IELTS',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: appRouter,
    );
  }
}
