import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_visuals.dart';
import '../services/supabase_service.dart';
import 'qr_screen.dart';

class LoginTiendaScreen extends StatefulWidget {
  const LoginTiendaScreen({super.key});

  @override
  State<LoginTiendaScreen> createState() => _LoginTiendaScreenState();
}

class _LoginTiendaScreenState extends State<LoginTiendaScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService.instance;

  bool _cargando = true;
  bool _procesando = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _verificarSesionGuardada();
  }

  String _normalizarCorreo(String valor) {
    return valor.trim().toLowerCase();
  }

  Future<void> _verificarSesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final idTienda = prefs.getString('id_tienda');
    final sessionId = prefs.getString('tienda_session_id');
    final tiendaGuardada = _tiendaGuardadaDesdePrefs(prefs);

    if (idTienda != null &&
        idTienda.isNotEmpty &&
        sessionId != null &&
        sessionId.isNotEmpty) {
      try {
        final sesionValida = await _supabaseService.renovarSesionTienda(
          idTienda: idTienda,
          sessionId: sessionId,
        );
        if (!sesionValida) {
          await _limpiarSesionLocal();
          if (mounted) {
            setState(() => _cargando = false);
          }
          return;
        }

        final tiendaActual = await _supabaseService.buscarTiendaPorId(idTienda);
        if (tiendaActual == null) {
          await _limpiarSesionLocal();
          if (mounted) {
            setState(() => _cargando = false);
          }
          return;
        }

        await _guardarSesionLocal(tiendaActual);
        if (!mounted) return;
        _abrirQr(tiendaActual, sessionId);
        return;
      } catch (_) {
        if (tiendaGuardada != null && mounted) {
          _abrirQr(tiendaGuardada, sessionId);
          return;
        }
      }
    }

    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Map<String, dynamic>? _tiendaGuardadaDesdePrefs(SharedPreferences prefs) {
    final idTienda = prefs.getString('id_tienda');
    final nombre = prefs.getString('nombre');
    final direccion = prefs.getString('direccion');
    final correo = prefs.getString('correo');

    if (idTienda == null ||
        idTienda.isEmpty ||
        nombre == null ||
        nombre.isEmpty ||
        direccion == null ||
        correo == null) {
      return null;
    }

    return {
      'id_tienda': idTienda,
      'nombre': nombre,
      'direccion': direccion,
      'correo': correo,
    };
  }

  Future<void> _limpiarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('id_tienda');
    await prefs.remove('nombre');
    await prefs.remove('direccion');
    await prefs.remove('correo');
    await prefs.remove('tienda_session_id');
  }

  Future<void> _guardarSesionLocal(
    Map<String, dynamic> tienda, {
    String? sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('id_tienda', tienda['id_tienda'] as String);
    await prefs.setString('nombre', tienda['nombre'] as String);
    await prefs.setString('direccion', tienda['direccion'] as String);
    await prefs.setString('correo', tienda['correo'] as String);
    if (sessionId != null) {
      await prefs.setString('tienda_session_id', sessionId);
    }
  }

  Future<void> _ingresar() async {
    final correoIngresado = _normalizarCorreo(_correoController.text);
    final passwordIngresado = _passwordController.text.trim();

    if (correoIngresado.isEmpty || passwordIngresado.isEmpty) {
      _mostrarMensaje('Ingresa tu correo y contrasena.');
      return;
    }

    setState(() => _procesando = true);

    try {
      final tienda = await _supabaseService.loginTienda(
        correo: correoIngresado,
        contrasena: passwordIngresado,
      );

      if (tienda == null) {
        _mostrarMensaje('Correo o contrasena incorrectos.');
        return;
      }

      await _supabaseService.asegurarQrEstatico(
        idTienda: tienda['id_tienda'] as String,
      );

      final sessionId = await _obtenerOSCrearSessionId();
      final sesion = await _supabaseService.iniciarSesionTienda(
        idTienda: tienda['id_tienda'] as String,
        sessionId: sessionId,
        dispositivo: 'app_qr',
      );

      if (sesion['permitido'] != true) {
        _mostrarMensaje(
          (sesion['mensaje'] ?? 'Esta tienda ya esta abierta.').toString(),
        );
        return;
      }

      await _guardarSesionLocal(tienda, sessionId: sessionId);

      if (!mounted) return;
      _abrirQr(tienda, sessionId);
    } catch (e) {
      _mostrarMensaje('Error iniciando sesion: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<String> _obtenerOSCrearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existente = prefs.getString('tienda_session_id');
    if (existente != null && existente.isNotEmpty) {
      return existente;
    }

    const chars = 'abcdef0123456789';
    final random = Random.secure();
    final sessionId = List.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    await prefs.setString('tienda_session_id', sessionId);
    return sessionId;
  }

  void _abrirQr(Map<String, dynamic> tienda, String sessionId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QRScreen(
          idTienda: tienda['id_tienda'] as String,
          nombreTienda: tienda['nombre'] as String,
          direccion: tienda['direccion'] as String,
          correo: tienda['correo'] as String,
          sessionId: sessionId,
        ),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: AppPalette.crimson),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'Panel de acceso',
                              style: GoogleFonts.robotoCondensed(
                                fontSize: 13,
                                color: AppPalette.textMuted,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR SUCURSAL',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 54,
                                  color: Colors.white,
                                  letterSpacing: 3.5,
                                  height: 0.95,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 86,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppPalette.crimson,
                                      AppPalette.electricBlue,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Accede con la cuenta asignada para mostrar el QR de la tienda.',
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 16,
                                  height: 1.35,
                                  color: AppPalette.textMuted,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'CORREO',
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _correoController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: appInputDecoration(
                                  hintText: 'correo@empresa.com',
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'CONTRASENA',
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_passwordVisible,
                                autocorrect: false,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                                decoration: appInputDecoration(
                                  hintText: 'Ingresa tu contrasena',
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _passwordVisible =
                                            !_passwordVisible,
                                      );
                                    },
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppPalette.crimson,
                                        AppPalette.crimsonDeep,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppPalette.crimson.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _procesando ? null : _ingresar,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _procesando
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'INGRESAR',
                                            style: GoogleFonts.robotoCondensed(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 3,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: Text(
                                  'Solo para uso del area de sistemas',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.robotoCondensed(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
