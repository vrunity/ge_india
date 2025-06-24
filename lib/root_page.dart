import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ScanPage.dart';
import 'loginpage.dart';
import 'SupervisorDashboard.dart';
import 'area_manager_dashboard.dart';
import 'EhsManagerDashboard.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final String? category = prefs.getString('category');

    if (category != null && category.isNotEmpty) {
      final String lowerCategory = category.toLowerCase().trim();

      if (lowerCategory == 'operator') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OperatorDashboard()),
        );
      } else if (lowerCategory == 'supervisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SupervisorDashboard()),
        );
      } else if (lowerCategory == 'area manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AreaManagerDashboard()),
        );
      } else if (lowerCategory == 'ehs manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EhsmanagerDashboard()),
        );
      }
    }
    else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF009688),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

