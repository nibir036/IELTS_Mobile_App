import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/reading/screens/reading_screen.dart';
import '../../features/writing/screens/writing_screen.dart';
import '../../features/listening/screens/listening_screen.dart';
import '../../features/speaking/screens/speaking_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/reading', builder: (context, state) => const ReadingScreen()),
    GoRoute(path: '/writing', builder: (context, state) => const WritingScreen()),
    GoRoute(path: '/listening', builder: (context, state) => const ListeningScreen()),
    GoRoute(path: '/speaking', builder: (context, state) => const SpeakingScreen()),
  ],
);
