import 'package:flutter/cupertino.dart';

class AppColors {
  static const background = Color(0xFFF7F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F1EC);
  static const line = Color(0x1A2C2C2E);
  static const lineStrong = Color(0x262C2C2E);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B6B6B);
  static const accent = Color(0xFF1B4D3E);
  static const accentSoft = Color(0xFFE5EEE9);
  static const rise = Color(0xFFC2514B);
  static const fall = Color(0xFF3E6E61);
  static const ma5 = Color(0xFF4B5E7A);
  static const ma10 = Color(0xFF8A7252);
  static const ma20 = Color(0xFF60766E);
  static const danger = Color(0xFFB64942);
}

CupertinoThemeData buildAppTheme() {
  return const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.accent,
    scaffoldBackgroundColor: AppColors.background,
    barBackgroundColor: AppColors.background,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.textPrimary,
      textStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.35,
      ),
      navTitleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
