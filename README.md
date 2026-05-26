# QR Dinámico - Requerimientos del Proyecto

Este documento detalla los componentes y configuraciones necesarios para ejecutar y compilar el proyecto de QR Dinámico.

## 1. Entorno de Desarrollo (SDK)
* **Flutter SDK:** ^3.11.5
* **Dart SDK:** Incluido con la versión de Flutter mencionada.
* **Plataformas Soportadas:** Android, iOS, Windows, Linux, Web.

## 2. Dependencias del Proyecto (pubspec.yaml)
El proyecto utiliza los siguientes paquetes de Flutter:
* `firebase_core`: Conexión base con Google Firebase.
* `cloud_firestore`: Base de datos en tiempo real para tokens y datos de tienda.
* `qr_flutter`: Generación visual de códigos QR.
* `google_fonts`: Tipografías *Bebas Neue* y *Roboto Condensed*.
* `shared_preferences`: Persistencia local de la sesión de la tienda.
* `intl`: Formateo de fechas y tiempos.

## 3. Configuración de Firebase (Firestore)
Para que la aplicación funcione, la base de datos en Firebase Console debe tener las siguientes colecciones:

### Colección `tienda`
Cada documento debe representar una sucursal con los campos:
* `correo` (String): Email de acceso.
* `password` (String): Contraseña de acceso.
* `id_tienda` (String): Identificador único.
* `nombre_tienda` (String).
* `nombre_sede` (String).
* `id_sede` (String).
* `direccion` (String).
* `usado` (Boolean): Control de sesión única.

### Colección `qr_activos`
Documentos indexados por el `id_tienda`:
* `activo` (Boolean).
* `token` (String): Token dinámico de 32 caracteres.
* `expira` (Timestamp): Tiempo de vida del QR.
* `id_tienda` / `id_sede` / `nombre_tienda`: Metadatos del QR.

## 4. Requerimientos de Compilación por OS

### Linux
Es necesario instalar las bibliotecas de desarrollo de GTK y herramientas de build:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

### Windows
* **Visual Studio 2022:** Con la carga de trabajo "Desktop development with C++" instalada.
* **Windows SDK:** Incluido con Visual Studio.

## 5. Activos (Assets)
El proyecto requiere la presencia de la imagen de fondo en:
`lib/assets/fondo.png`

## 6. Ejecución
1. Ejecutar `flutter pub get` para instalar dependencias.
2. Ejecutar `flutter run` en el dispositivo o plataforma deseada.# Qr_Empresa
