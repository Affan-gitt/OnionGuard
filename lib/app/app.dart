import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'theme.dart';
import '../features/splash/screens/splash_screen.dart';

class OnionGuardApp extends StatelessWidget {
  const OnionGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
