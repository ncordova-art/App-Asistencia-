import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_visuals.dart';
import '../services/supabase_service.dart';
import 'login_tienda_screen.dart';

class QRScreen extends StatefulWidget {
  final String idTienda;
  final String nombreTienda;
  final String direccion;
  final String correo;
  final String sessionId;

  const QRScreen({
    super.key,
    required this.idTienda,
    required this.nombreTienda,
    required this.direccion,
    required this.correo,
    required this.sessionId,
  });

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final _supabaseService = SupabaseService.instance;

  String _qrData = '';
  bool _cargando = true;
  String? _errorQr;
  int _segundosRestantes = 30;
  Timer? _timerQr;
  Timer? _timerSesion;

  @override
  void initState() {
    super.initState();
    _prepararQr();
    _iniciarTimers();
  }

  @override
  void dispose() {
    _timerQr?.cancel();
    _timerSesion?.cancel();
    super.dispose();
  }

  void _iniciarTimers() {
    _timerQr?.cancel();
    _timerSesion?.cancel();

    _timerQr = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _cargando || _errorQr != null) return;
      if (_segundosRestantes <= 1) {
        _prepararQr(mostrarCarga: false);
      } else {
        setState(() => _segundosRestantes--);
      }
    });

    _timerSesion = Timer.periodic(const Duration(seconds: 15), (_) {
      _renovarSesion();
    });
  }

  Future<void> _renovarSesion() async {
    try {
      final activa = await _supabaseService.renovarSesionTienda(
        idTienda: widget.idTienda,
        sessionId: widget.sessionId,
      );

      if (!activa && mounted) {
        await _limpiarSesionLocal();
        setState(() {
          _errorQr = 'La tienda fue abierta en otro dispositivo.';
          _cargando = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorQr = 'No se pudo renovar la sesion: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _prepararQr({bool mostrarCarga = true}) async {
    setState(() {
      _cargando = mostrarCarga;
      _errorQr = null;
    });

    try {
      final qr = await _supabaseService.obtenerPayloadQrTienda(
        idTienda: widget.idTienda,
        sessionId: widget.sessionId,
      );

      if (!mounted) return;
      setState(() {
        _qrData = qr['payload'].toString();
        _segundosRestantes = 30;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorQr = 'No se pudo preparar el QR: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Cerrar sesion',
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'Seguro que quieres cerrar sesion en esta tienda?',
          style: GoogleFonts.robotoCondensed(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesion',
              style: TextStyle(color: AppPalette.crimson),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _supabaseService.cerrarSesionTienda(
      idTienda: widget.idTienda,
      sessionId: widget.sessionId,
    );
    await _limpiarSesionLocal();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginTiendaScreen()),
    );
  }

  Future<void> _limpiarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('id_tienda');
    await prefs.remove('nombre');
    await prefs.remove('direccion');
    await prefs.remove('correo');
    await prefs.remove('tienda_session_id');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR TIENDA',
              style: GoogleFonts.bebasNeue(
                fontSize: 20,
                letterSpacing: 2.4,
                color: Colors.white,
              ),
            ),
            Text(
              widget.nombreTienda,
              style: GoogleFonts.robotoCondensed(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
              child: FrostedPanel(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: CircularProgressIndicator(color: AppPalette.crimson),
        ),
      );
    }

    if (_errorQr != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 54,
            color: Colors.white.withValues(alpha: 0.88),
          ),
          const SizedBox(height: 16),
          Text(
            _errorQr!,
            textAlign: TextAlign.center,
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              height: 1.35,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _prepararQr,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.crimson,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Reintentar',
              style: GoogleFonts.robotoCondensed(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.crimson, AppPalette.electricBlueSoft],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Activo',
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.crimson.withValues(alpha: 0.16),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData,
                  size: 270,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.nombreTienda.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            fontSize: 30,
            color: Colors.white,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.correo,
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoCondensed(
            fontSize: 15,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.direccion,
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoCondensed(
            fontSize: 13,
            height: 1.35,
            color: Colors.white54,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF4ECA8B).withValues(alpha: 0.12),
            border: Border.all(
              color: const Color(0xFF4ECA8B).withValues(alpha: 0.42),
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                color: Color(0xFF4ECA8B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Token QR activo',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 15,
                    color: const Color(0xFF4ECA8B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _segundosRestantes / 30,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ECA8B)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Actualiza en $_segundosRestantes segundos',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoCondensed(
            fontSize: 13,
            color: Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
