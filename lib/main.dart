import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_visuals.dart';
import 'firebase_options.dart';
import 'screens/login_tienda_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const QRApp());
}

class QRApp extends StatelessWidget {
  const QRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Sucursal',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppPalette.night,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.crimson,
          secondary: AppPalette.electricBlue,
          surface: AppPalette.night,
        ),
        textTheme: GoogleFonts.robotoCondensedTextTheme(
          ThemeData.dark().textTheme,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppPalette.crimson,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const LoginTiendaScreen(),
    );
  }
}
