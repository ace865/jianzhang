import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class InkColors {
  InkColors(this.dark);
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF242321) : const Color(0xFFFAF9F6);
  Color get panel => dark ? const Color(0xFF302E2B) : const Color(0xFFFFFEFB);
  Color get border => dark ? const Color(0xFF44403B) : const Color(0xFFEAE5DD);
  Color get ink => dark ? const Color(0xFFEFE8DC) : const Color(0xFF302E2A);
  Color get muted => dark ? const Color(0xFFB5ACA0) : const Color(0xFF7B746D);
  Color get accent => dark ? const Color(0xFFE39876) : const Color(0xFFBC6243);
  Color get onAccent => dark ? const Color(0xFF28231F) : Colors.white;
  Color get income => dark ? const Color(0xFFACC193) : const Color(0xFF47794F);
  Color get danger => dark ? const Color(0xFFF1A091) : const Color(0xFFAA4235);
  List<Color> get chart => [
    accent,
    dark ? const Color(0xFFACBB96) : const Color(0xFF93A783),
    const Color(0xFFE2B574),
    const Color(0xFFA99A88),
    const Color(0xFF9295A4),
    const Color(0xFFB494A0),
    const Color(0xFF6E9B95),
    const Color(0xFFD4BEAA),
  ];
  static InkColors of(BuildContext context) =>
      InkColors(Theme.of(context).brightness == Brightness.dark);
}

ThemeData ledgerTheme(bool dark) {
  final ink = InkColors(dark);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ink.accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: ink.accent,
        onPrimary: ink.onAccent,
        surface: ink.panel,
        onSurface: ink.ink,
        outline: ink.border,
        error: ink.danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink.background,
    fontFamilyFallback: const ['sans-serif'],
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: ink.ink,
        fontFamily: 'LedgerSerif',
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w600,
        color: ink.ink,
        fontFamily: 'LedgerSerif',
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: ink.ink),
      bodyMedium: TextStyle(fontSize: 14, color: ink.ink),
      bodySmall: TextStyle(fontSize: 12, color: ink.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ink.background,
      foregroundColor: ink.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(color: ink.border, thickness: 0.7, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ink.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ink.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ink.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ink.background,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFEFE8DC) : const Color(0xFF302E2A),
      contentTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: dark ? const Color(0xFF302E2A) : Colors.white,
      ),
    ),
  );
}

IconData categoryGlyph(String name) => switch (name) {
  'utensils' => LucideIcons.utensils,
  'train' => LucideIcons.trainFront,
  'shopping' => LucideIcons.shoppingCart,
  'home' => LucideIcons.house,
  'game' => LucideIcons.gamepad2,
  'medical' => LucideIcons.cross,
  'book' => LucideIcons.bookOpen,
  'briefcase' => LucideIcons.briefcaseBusiness,
  'gift' => LucideIcons.gift,
  'coffee' => LucideIcons.coffee,
  _ => LucideIcons.ellipsis,
};
