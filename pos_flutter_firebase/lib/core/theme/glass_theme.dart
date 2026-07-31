import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const accent = Color(0xFFF76707);
  static const accentLight = Color(0xFFFFF4E6);
  static const accentDark = Color(0xFFE65100);
  static const success = Color(0xFF40C057);
  static const successLight = Color(0xFFEBFBEE);
  static const warning = Color(0xFFFD7E14);
  static const warningLight = Color(0xFFFFF4E6);
  static const danger = Color(0xFFFA5252);
  static const dangerLight = Color(0xFFFFE3E3);

  static const lightBg = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE9ECEF);
  static const lightText = Color(0xFF1A1B1E);
  static const lightTextSecondary = Color(0xFF868E96);
  static const lightTextTertiary = Color(0xFFADB5BD);

  static const darkBg = Color(0xFF1A1B1E);
  static const darkSurface = Color(0xFF25262B);
  static const darkBorder = Color(0xFF373A40);
  static const darkText = Color(0xFFF1F3F5);
  static const darkTextSecondary = Color(0xFFADB5BD);
  static const darkTextTertiary = Color(0xFF6C757D);
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.lightSurface,
      error: AppColors.danger,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lightText, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.lightText, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightText),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.lightText),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.lightText),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.lightText, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.lightText, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.lightText, letterSpacing: 0.2),
      labelSmall: TextStyle(fontSize: 11, color: AppColors.lightTextTertiary, letterSpacing: 0.3),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.lightText, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: AppColors.lightTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: AppColors.lightBorder),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightBg,
      selectedColor: AppColors.accentLight,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.lightText),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: const BorderSide(color: AppColors.lightBorder),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 0.5,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightText),
      contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.lightText),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.accentLight,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      labelType: NavigationRailLabelType.none,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: AppColors.lightBorder)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.zero,
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.lightText),
      subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.danger,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkText, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkText),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkText),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.darkText, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.darkText, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText, letterSpacing: 0.2),
      labelSmall: TextStyle(fontSize: 11, color: AppColors.darkTextTertiary, letterSpacing: 0.3),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: AppColors.darkTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: AppColors.darkBorder),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkText),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 0.5,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkText),
      contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.darkText),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.accentLight,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      labelType: NavigationRailLabelType.none,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: AppColors.darkBorder)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.zero,
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.darkText),
      subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
    ),
  );
}

// backward compatibility
typedef GlassColors = AppColors;
typedef GlassTheme = AppTheme;
