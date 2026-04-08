import 'package:flutter/material.dart';

class DesktopColors {
  static const primary = Color(0xB30123C9);
  static const primaryDark = Color(0x9370EAFF);
  static const background = Color(0xFFF4F6F9);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class DesktopTextStyles {
  static const heading1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: DesktopColors.textPrimary,
  );

  static const heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: DesktopColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: DesktopColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 14,
    color: DesktopColors.textSecondary,
  );
}

class DesktopButtonTheme {
  static ElevatedButtonThemeData elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DesktopColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class DesktopInputTheme {
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DesktopColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DesktopColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DesktopColors.primary, width: 2),
    ),
  );
}

class DesktopSpacing {
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 48.0;
}

class DesktopTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: DesktopColors.background,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: DesktopColors.primary,
      onPrimary: Colors.white,
      secondary: DesktopColors.primaryDark,
      onSecondary: Colors.white,
      error: Colors.red,
      onError: Colors.white,
      background: DesktopColors.background,
      onBackground: DesktopColors.textPrimary,
      surface: DesktopColors.surface,
      onSurface: DesktopColors.textPrimary,
    ),
    textTheme: const TextTheme(
      displayLarge: DesktopTextStyles.heading1,
      headlineMedium: DesktopTextStyles.heading2,
      bodyLarge: DesktopTextStyles.body,
      bodySmall: DesktopTextStyles.caption,
    ),
    inputDecorationTheme: DesktopInputTheme.inputDecorationTheme,
    elevatedButtonTheme: DesktopButtonTheme.elevatedButtonTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: DesktopColors.surface,
      foregroundColor: DesktopColors.textPrimary,
      elevation: 0,
    ),
  );
}

class CustomDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CustomDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      // التصميم الثابت لجميع جداول النظام
      headingRowColor: const WidgetStatePropertyAll(DesktopColors.background),
      horizontalMargin: DesktopSpacing.xs,
      columnSpacing: DesktopSpacing.sm,

      // البيانات الديناميكية التي يتم تمريرها
      columns: columns,
      rows: rows,
    );
  }
}
