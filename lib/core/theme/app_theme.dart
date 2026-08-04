import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (Light Mode)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);
  
  static const Color blue600 = Color(0xFF2563EB); // Primary
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color green600 = Color(0xFF16A34A); // Secondary
  
  static const Color red600 = Color(0xFFDC2626); // Error
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red800 = Color(0xFF991B1B);
  
  static const Color yellow600 = Color(0xFFD97706); // Warning
  static const Color yellow100 = Color(0xFFFEF3C7);
  static const Color yellow800 = Color(0xFF92400E);
  
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green800 = Color(0xFF166534);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: blue600,
      scaffoldBackgroundColor: slate50,
      colorScheme: const ColorScheme.light(
        primary: blue600,
        secondary: green600,
        error: red600,
        surface: white,
        onSurface: slate900,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: slate900,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: slate900,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: blue600, width: 2.0),
        ),
        labelStyle: const TextStyle(color: slate500, fontSize: 14.0),
        hintStyle: const TextStyle(color: slate500, fontSize: 14.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue600,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
