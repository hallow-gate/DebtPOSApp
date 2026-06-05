import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Marnie Store POS';
  static const String appVersion = 'v2.1';
  static const String localDbBox = 'marnie_pos_local';
  
  // Collection names
  static const String productsCollection = 'products';
  static const String customersCollection = 'customers';
  static const String purchasesCollection = 'purchases';
}

class AppColors {
  static const Color primary = Color(0xFF4e73df);
  static const Color success = Color(0xFF1cc88a);
  static const Color warning = Color(0xFFf6c23e);
  static const Color danger = Color(0xFFe74a3b);
  static const Color info = Color(0xFF36b9cc);
  
  static const Color background = Color(0xFF0f0f1a);
  static const Color surface = Color(0xFF1a1a2e);
  static const Color surfaceLight = Color(0xFF262640);
   static const Color cardBackground = Color(0x0Cffffff); 
  static const Color border = Color(0x1Affffff);         
  static const Color inputBackground = Color(0x0Cffffff); 
  
  static const Color textPrimary = Color(0xFFffffff);
  static const Color textSecondary = Color(0x80ffffff);
  static const Color textMuted = Color(0x66ffffff);
  
  static const Color gradientStart = Color(0xFF4e73df);
  static const Color gradientEnd = Color(0xFF1cc88a);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppTypography {
  static const double heading1 = 28;
  static const double heading2 = 22;
  static const double heading3 = 18;
  static const double body = 14;
  static const double small = 12;
  static const double tiny = 10;
}
