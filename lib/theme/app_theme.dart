import 'package:flutter/material.dart';

class AppTheme {
  // Custom color palette
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color accentBlue = Color(0xFF64B5F6);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFF7F8C8D);
  static const Color white = Colors.white;
  static const Color backgroundGrey = Color(0xFFF5F7FA);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkText = Color(0xFFB0BEC5);
  static const Color darkSurface = Color(0xFF333333);

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      // Main colors
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentBlue,
        onPrimary: white,
        onSecondary: white,
        background: backgroundGrey,
        surface: white,
      ),

      // Scaffold and background colors
      scaffoldBackgroundColor: backgroundGrey,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),

      // Card theme
      cardTheme: CardTheme(
        color: white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: darkBlue.withOpacity(0.1),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: primaryBlue.withOpacity(0.5),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        floatingLabelStyle: const TextStyle(color: primaryBlue),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return white;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return accentBlue;
          }
          return textLight.withOpacity(0.4);
        }),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryBlue,
        inactiveTrackColor: lightBlue,
        thumbColor: white,
        overlayColor: primaryBlue.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorTextStyle: const TextStyle(color: white),
        valueIndicatorColor: darkBlue,
        trackShape: const RoundedRectSliderTrackShape(),
      ),

      // Text themes
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        displayMedium: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        displaySmall: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        headlineLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        headlineMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        headlineSmall: TextStyle(color: textDark, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        titleSmall: TextStyle(color: textDark, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        bodyLarge: TextStyle(color: textDark, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(color: textDark, fontFamily: 'Poppins'),
        bodySmall: TextStyle(color: textLight, fontFamily: 'Poppins'),
        labelLarge: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        labelMedium: TextStyle(color: primaryBlue, fontFamily: 'Poppins'),
        labelSmall: TextStyle(color: textLight, fontFamily: 'Poppins'),
      ),

      // Other theme configurations
      dividerTheme: const DividerThemeData(
        color: lightBlue,
        thickness: 1,
        space: 24,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return white;
        }),
        side: BorderSide(color: accentBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return textLight;
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      // Main colors
      primaryColor: darkBlue,
      colorScheme: const ColorScheme.dark(
        primary: darkBlue,
        secondary: accentBlue,
        onPrimary: white,
        onSecondary: white,
        background: darkBackground,
        surface: darkSurface,
      ),

      // Scaffold and background colors
      scaffoldBackgroundColor: darkBackground,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBlue,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),

      // Card theme
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: darkBlue.withOpacity(0.1),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: darkBlue.withOpacity(0.5),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkBlue,
          side: const BorderSide(color: darkBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        floatingLabelStyle: const TextStyle(color: darkBlue),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return darkBlue;
          }
          return white;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return accentBlue;
          }
          return textLight.withOpacity(0.4);
        }),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: darkBlue,
        inactiveTrackColor: lightBlue,
        thumbColor: white,
        overlayColor: darkBlue.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorTextStyle: const TextStyle(color: white),
        valueIndicatorColor: darkBlue,
        trackShape: const RoundedRectSliderTrackShape(),
      ),

      // Text themes
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        bodyLarge: TextStyle(color: darkText, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(color: darkText, fontFamily: 'Poppins'),
        bodySmall: TextStyle(color: darkText, fontFamily: 'Poppins'),
        labelLarge: TextStyle(color: darkBlue, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
        labelMedium: TextStyle(color: darkBlue, fontFamily: 'Poppins'),
        labelSmall: TextStyle(color: darkText, fontFamily: 'Poppins'),
      ),

      // Other theme configurations
      dividerTheme: const DividerThemeData(
        color: lightBlue,
        thickness: 1,
        space: 24,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return darkBlue;
          }
          return white;
        }),
        side: BorderSide(color: accentBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return darkBlue;
          }
          return darkText;
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkBlue,
        unselectedItemColor: darkText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

// How to use this theme in your main.dart file:
/*
import 'path_to_this_file/app_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: AppTheme.lightTheme, // or AppTheme.darkTheme for dark mode
      home: HomePage(),
    );
  }
}
*/
