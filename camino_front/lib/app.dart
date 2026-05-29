import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_theme.dart';
import 'package:camino_front/shared/constants/app_routes.dart';
import 'package:camino_front/shared/constants/app_strings.dart';
import 'package:camino_front/features/splash/screens/splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
      routes: AppRoutes.routes,
    );
  }
}
