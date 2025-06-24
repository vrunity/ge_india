import 'package:flutter/material.dart';
import 'package:ge_india/root_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GE Vernova',
      theme: ThemeData(
        primaryColor: const Color(0xFF00695C),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: const Color(0xFFC0FF33)),
      ),
      // 2️⃣ point home at your AuthPage (the tab controller with Login/Signup)
      home:  SplashPage(),
    );
  }
}

