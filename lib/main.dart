import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const SahelCashApp());
}

class SahelCashApp extends StatelessWidget {
  const SahelCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سهل كاش',
      home: const HomeScreen(),
    );
  }
}
