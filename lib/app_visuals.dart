import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color night = Color(0xFF030303);
  static const Color crimson = Color(0xFFD10A0A);
  static const Color crimsonDeep = Color(0xFF6B0202);
  static const Color electricBlue = Color(0xFF153A97);
  static const Color electricBlueSoft = Color(0xFF0B1D63);
  static const Color card = Color(0xCC0C0C0F);
  static const Color cardBorder = Color(0x33FFFFFF);
  static const Color textMuted = Color(0xB3FFFFFF);
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('lib/assets/fondo.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.62),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

InputDecoration appInputDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    hintText: hintText,
    hintStyle: GoogleFonts.robotoCondensed(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 15,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppPalette.crimson, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    suffixIcon: suffixIcon,
  );
}
