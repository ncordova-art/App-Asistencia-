import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_visuals.dart';
import 'qr_screen.dart';

class LoginTiendaScreen extends StatefulWidget {
  const LoginTiendaScreen({super.key});

  @override
  State<LoginTiendaScreen> createState() => _LoginTiendaScreenState();
}

class _LoginTiendaScreenState extends State<LoginTiendaScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();

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

  Map<String, dynamic> _mapearTienda(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return {
      'docId': doc.id,
      'id_tienda': (data['id_tienda'] ?? doc.id).toString(),
      'nombre_tienda': (data['nombre_tienda'] ?? '').toString(),
      'nombre_sede': (data['nombre_sede'] ?? '').toString(),
      'id_sede': (data['id_sede'] ?? '').toString(),
      'direccion': (data['direccion'] ?? '').toString(),
      'correo': (data['correo'] ?? '').toString().trim(),
      'password': (data['password'] ?? data['contrasena'] ?? '').toString(),
      'usado': data['usado'] == true,
    };
  }

  Future<Map<String, dynamic>?> _buscarTiendaPorDocId(String docId) async {
    final doc =
        await FirebaseFirestore.instance.collection('tienda').doc(docId).get();

    if (!doc.exists) {
      return null;
    }

    return _mapearTienda(doc);
  }

  Future<void> _verificarSesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final tiendaDocId = prefs.getString('tienda_doc_id');

    if (tiendaDocId != null) {
      try {
        final tiendaActual = await _buscarTiendaPorDocId(tiendaDocId);
        if (tiendaActual == null) {
          await _limpiarSesionLocal();
          if (mounted) {
            setState(() => _cargando = false);
          }
          return;
        }

        await FirebaseFirestore.instance
            .collection('tienda')
            .doc(tiendaDocId)
            .set({'usado': true}, SetOptions(merge: true));

        await prefs.setString('id_tienda', tiendaActual['id_tienda'] as String);
        await prefs.setString(
          'nombre_tienda',
          tiendaActual['nombre_tienda'] as String,
        );
        await prefs.setString(
          'nombre_sede',
          tiendaActual['nombre_sede'] as String,
        );
        await prefs.setString('id_sede', tiendaActual['id_sede'] as String);
        await prefs.setString(
          'direccion',
          tiendaActual['direccion'] as String,
        );
        await prefs.setString('correo', tiendaActual['correo'] as String);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QRScreen(
              tiendaDocId: tiendaDocId,
              idTienda: tiendaActual['id_tienda'] as String,
              nombreTienda: tiendaActual['nombre_tienda'] as String,
              nombreSede: tiendaActual['nombre_sede'] as String,
              idSede: tiendaActual['id_sede'] as String,
              direccion: tiendaActual['direccion'] as String,
              correo: tiendaActual['correo'] as String,
            ),
          ),
        );
        return;
      } catch (_) {
        await _limpiarSesionLocal();
      }
    }

    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _limpiarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tienda_doc_id');
    await prefs.remove('id_tienda');
    await prefs.remove('nombre_tienda');
    await prefs.remove('nombre_sede');
    await prefs.remove('id_sede');
    await prefs.remove('direccion');
    await prefs.remove('correo');
  }

  Future<Map<String, dynamic>?> _buscarTiendaPorCorreo(String correo) async {
    final correoNormalizado = _normalizarCorreo(correo);
    final snapExacto = await FirebaseFirestore.instance
        .collection('tienda')
        .where('correo', isEqualTo: correoNormalizado)
        .limit(1)
        .get();

    if (snapExacto.docs.isNotEmpty) {
      return _mapearTienda(snapExacto.docs.first);
    }

    final snap = await FirebaseFirestore.instance.collection('tienda').get();

    for (final doc in snap.docs) {
      final tienda = _mapearTienda(doc);
      if (_normalizarCorreo(tienda['correo'] as String) == correoNormalizado) {
        return tienda;
      }
    }

    return null;
  }

  Future<bool> _validarQrActivo(Map<String, dynamic> tienda) async {
    final qrActivoDoc = await FirebaseFirestore.instance
        .collection('qr_activos')
        .doc(tienda['id_tienda'] as String)
        .get();

    if (!qrActivoDoc.exists) {
      _mostrarMensaje('No se encontró un QR activo para esta tienda.');
      return false;
    }

    final data = qrActivoDoc.data();
    if (data == null) {
      _mostrarMensaje('El documento QR activo es inválido.');
      return false;
    }

    final activo = data['activo'] as bool?;
    final idTiendaQr = (data['id_tienda'] ?? qrActivoDoc.id).toString();

    if (activo != true || idTiendaQr != tienda['id_tienda']) {
      _mostrarMensaje('El QR activo no coincide con la tienda registrada.');
      return false;
    }

    return true;
  }

  Future<void> _ingresar() async {
    final correoIngresado = _normalizarCorreo(_correoController.text);
    final passwordIngresado = _passwordController.text.trim();

    if (correoIngresado.isEmpty || passwordIngresado.isEmpty) {
      _mostrarMensaje('Ingresa tu correo y contraseña.');
      return;
    }

    setState(() => _procesando = true);

    try {
      final tienda = await _buscarTiendaPorCorreo(correoIngresado);

      if (tienda == null) {
        _mostrarMensaje('No existe una tienda con ese correo.');
        return;
      }

      if (passwordIngresado != tienda['password']) {
        _mostrarMensaje('La contraseña es incorrecta.');
        return;
      }

      if (tienda['usado'] == true) {
        _mostrarMensaje('Esta cuenta ya está en uso en otro dispositivo.');
        return;
      }

      final qrActivoValido = await _validarQrActivo(tienda);
      if (!qrActivoValido) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('tienda')
          .doc(tienda['docId'] as String)
          .set({'usado': true}, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tienda_doc_id', tienda['docId'] as String);
      await prefs.setString('id_tienda', tienda['id_tienda'] as String);
      await prefs.setString('nombre_tienda', tienda['nombre_tienda'] as String);
      await prefs.setString('nombre_sede', tienda['nombre_sede'] as String);
      await prefs.setString('id_sede', tienda['id_sede'] as String);
      await prefs.setString('direccion', tienda['direccion'] as String);
      await prefs.setString('correo', tienda['correo'] as String);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QRScreen(
            tiendaDocId: tienda['docId'] as String,
            idTienda: tienda['id_tienda'] as String,
            nombreTienda: tienda['nombre_tienda'] as String,
            nombreSede: tienda['nombre_sede'] as String,
            idSede: tienda['id_sede'] as String,
            direccion: tienda['direccion'] as String,
            correo: tienda['correo'] as String,
          ),
        ),
      );
    } catch (e) {
      _mostrarMensaje('Error iniciando sesión: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
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
                                'Accede con la cuenta asignada para mostrar el QR dinámico de la sede.',
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
                                'CONTRASEÑA',
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
                                  hintText: 'Ingresa tu contraseña',
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
                                  'Solo para uso del área de sistemas',
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
