import 'package:flutter/material.dart';
import 'package:camino_front/features/auth/screens/login_screen.dart';
import 'package:camino_front/features/auth/screens/register_screen.dart';
import 'package:camino_front/features/routing/screens/starting_screen.dart';
import 'package:camino_front/features/routing/screens/route_details_screen.dart';
import 'package:camino_front/features/routing/screens/navigation_screen.dart';
import 'package:camino_front/features/reporting/screens/report_barrier_screen.dart';
import 'package:camino_front/features/reporting/screens/barrier_confirmed_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const login            = '/login';
  static const register         = '/register';
  static const home             = '/';
  static const routeDetails     = '/route-details';
  static const navigation       = '/navigation';
  static const reportBarrier    = '/report-barrier';
  static const barrierConfirmed = '/barrier-confirmed';

  static Map<String, WidgetBuilder> get routes => {
    login:            (_) => const LoginScreen(),
    register:         (_) => const RegisterScreen(),
    home:             (_) => const MapScreen(),
    routeDetails:     (_) => const RouteDetailsScreen(),
    navigation:       (_) => const NavigationScreen(),
    reportBarrier:    (_) => const ReportBarrierScreen(),
    barrierConfirmed: (_) => const BarrierConfirmedScreen(),
  };
}
