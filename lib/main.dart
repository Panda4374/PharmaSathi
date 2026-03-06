import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(
    const MyApp()
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PharmaSathi",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: '.SF Pro Text',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: '.SF Pro Display'),
          displayMedium: TextStyle(fontFamily: '.SF Pro Display'),
          displaySmall: TextStyle(fontFamily: '.SF Pro Display'),
          headlineLarge: TextStyle(fontFamily: '.SF Pro Display'),
          headlineMedium: TextStyle(fontFamily: '.SF Pro Display'),
          headlineSmall: TextStyle(fontFamily: '.SF Pro Display'),
          titleLarge: TextStyle(fontFamily: '.SF Pro Text'),
          titleMedium: TextStyle(fontFamily: '.SF Pro Text'),
          titleSmall: TextStyle(fontFamily: '.SF Pro Text'),
          bodyLarge: TextStyle(fontFamily: '.SF Pro Text'),
          bodyMedium: TextStyle(fontFamily: '.SF Pro Text'),
          bodySmall: TextStyle(fontFamily: '.SF Pro Text'),
          labelLarge: TextStyle(fontFamily: '.SF Pro Text'),
          labelMedium: TextStyle(fontFamily: '.SF Pro Text'),
          labelSmall: TextStyle(fontFamily: '.SF Pro Text'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
