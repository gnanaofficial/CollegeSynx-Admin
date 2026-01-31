import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate GIF duration (adjust if needed based on actual GIF length)
    Timer(const Duration(seconds: 7), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background as requested
      body: SizedBox.expand(
        child: Image.asset('assets/images/splash.gif', fit: BoxFit.cover),
      ),
    );
  }
}
