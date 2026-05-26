import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_visuals.dart';
import 'login_tienda_screen.dart';

class QRScreen extends StatefulWidget {
  final String tiendaDocId;
  final String idTienda;
  final String nombreTienda;
  final String nombreSede;
  final String idSede;
  final String direccion;
  final String correo;

  const QRScreen({
    super.key,
    required this.tiendaDocId,
    required this.idTienda,
    required this.nombreTienda,
    required this.nombreSede,
    required this.idSede,
    required this.direccion,
    required this.correo,
  });

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  String _qrData = '';
  int _segundosRestantes = 30;
  Timer? _timerQR;
  Timer? _timerContador;
  bool _generando = false;
  bool _qrActivoValido = false;
  String? _errorQrActivo;

  @override
  void initState() {
    super.initState();
    _verificarYIniciar();
  }

  @override
  void dispose() {
    _timerQR?.cancel();
    _timerContador?.cancel();
    super.dispose();
  }

  void _iniciarTimers() {
    _timerQR?.cancel();
    _timerContador?.cancel();

    _timerQR = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _generarQR();
      if (mounted) {
        setState(() => _segundosRestantes = 30);
      }
    });

    _timerContador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosRestantes > 0) {
        setState(() => _segundosRestantes--);
      }
    });
  }

  Future<void> _verificarYIniciar() async {
    final valido = await _verificarEstadoQrActivo();
    if (!mounted) return;

    if (!valido) {
      setState(() {
        _qrActivoValido = false;
        _errorQrActivo =
            'El QR activo no está habilitado o no coincide con esta tienda.';
      });
      return;
    }

    setState(() {
      _qrActivoValido = true;
      _errorQrActivo = null;
      _segundosRestantes = 30;
    });

    await _generarQR();
    _iniciarTimers();
  }

  Future<bool> _verificarEstadoQrActivo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('qr_activos')
          .doc(widget.idTienda)
          .get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      if (data == null) {
        return false;
      }

      final activo = data['activo'] as bool?;
      final idTiendaQr = (data['id_tienda'] ?? doc.id).toString();

      return activo == true && idTiendaQr == widget.idTienda;
    } catch (_) {
      return false;
    }
  }

  String _generarToken() {
    const chars = 'abcdef0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _generarQR() async {
    if (_generando || !_qrActivoValido) return;
    _generando = true;

    final sigueValido = await _verificarEstadoQrActivo();
    if (!sigueValido) {
      if (mounted) {
        setState(() {
          _qrActivoValido = false;
          _errorQrActivo = 'El QR activo fue deshabilitado.';
        });
      }
      _generando = false;
      return;
    }

    try {
      final nuevoToken = _generarToken();
      final expira = DateTime.now().add(const Duration(seconds: 30));

      final qrData = {
        'token': nuevoToken,
        'id_tienda': widget.idTienda,
        'id_sede': widget.idSede,
        'nombre_tienda': widget.nombreTienda,
        'nombre_sede': widget.nombreSede,
        'direccion': widget.direccion,
      };

      await FirebaseFirestore.instance
          .collection('qr_activos')
          .doc(widget.idTienda)
          .set({
            'activo': true,
            'direccion': widget.direccion,
            'fecha_creada': FieldValue.serverTimestamp(),
            'expira': Timestamp.fromDate(expira),
            'id_sede': widget.idSede,
            'id_tienda': widget.idTienda,
            'nombre_sede': widget.nombreSede,
            'nombre_tienda': widget.nombreTienda,
            'token': nuevoToken,
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _qrData = jsonEncode(qrData);
          _segundosRestantes = 30;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generando QR: $e')));
      }
    } finally {
      _generando = false;
    }
  }

  Future<void> _liberarUsoTienda() async {
    await FirebaseFirestore.instance
        .collection('tienda')
        .doc(widget.tiendaDocId)
        .set({'usado': false}, SetOptions(merge: true));
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          '¿Seguro que quieres cerrar sesión en esta tienda?',
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
              'Cerrar sesión',
              style: TextStyle(color: AppPalette.crimson),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _liberarUsoTienda();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo liberar la cuenta: $e')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tienda_doc_id');
    await prefs.remove('id_tienda');
    await prefs.remove('nombre_tienda');
    await prefs.remove('nombre_sede');
    await prefs.remove('id_sede');
    await prefs.remove('direccion');
    await prefs.remove('correo');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginTiendaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color colorCountdown;
    if (_segundosRestantes > 10) {
      colorCountdown = const Color(0xFF4ECA8B);
    } else if (_segundosRestantes > 5) {
      colorCountdown = Colors.orange;
    } else {
      colorCountdown = AppPalette.crimson;
    }

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
              'QR DINÁMICO',
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
            tooltip: 'Cerrar sesión',
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
                child: _errorQrActivo != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 54,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorQrActivo!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoCondensed(
                              fontSize: 16,
                              height: 1.35,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _verificarYIniciar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.crimson,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
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
                      )
                    : _qrData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 56),
                        child: CircularProgressIndicator(
                          color: AppPalette.crimson,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
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
                                        colors: [
                                          AppPalette.crimson,
                                          AppPalette.electricBlueSoft,
                                        ],
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
                                        color: AppPalette.crimson.withValues(
                                          alpha: 0.16,
                                        ),
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
                            widget.nombreSede,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoCondensed(
                              fontSize: 16,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: colorCountdown.withValues(alpha: 0.12),
                              border: Border.all(
                                color: colorCountdown.withValues(alpha: 0.42),
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: colorCountdown,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Cambia en $_segundosRestantes segundos',
                                    style: GoogleFonts.robotoCondensed(
                                      fontSize: 15,
                                      color: colorCountdown,
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
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorCountdown,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
