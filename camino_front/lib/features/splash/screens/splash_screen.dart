import 'package:flutter/material.dart';
import 'package:camino_front/features/auth/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _opacity = 1.0);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_icon.png',
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFF4285F4),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
