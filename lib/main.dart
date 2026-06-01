import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_visuals.dart';
import 'screens/login_tienda_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseOptions.supabaseUrl,
    anonKey: SupabaseOptions.supabaseKey,
  );
  runApp(const QRApp());
}

class SupabaseOptions {
  static const String supabaseUrl = 'https://tlmsnenvqqblmmtimung.supabase.co';
  static const String supabaseKey =
      'sb_publishable_wnlnQ6sVmbsvHjklJx1uOw_sxhxC2aw';
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
