# SGI LAB MANAGER — Frontend

Aplicación multi-plataforma (Linux, Android, Web) para la gestión del laboratorio integrado del PCJIC Rionegro, Colombia. Desarrollada en **Flutter**.

---

## Stack tecnológico

| Tecnología | Uso |
| --- | --- |
| Flutter 3 / Dart | UI multi-plataforma |
| Provider | Gestión de estado |
| Dio | Cliente HTTP + interceptor JWT |
| sqflite + sqflite_common_ffi | Base de datos local (SQLite) para modo offline |
| connectivity_plus | Detección de red para sync offline |
| qr_flutter | Generación de códigos QR |
| flutter_secure_storage | Almacenamiento seguro de tokens |
| file_picker | Selección de archivos (PDF de FDS) |
| url_launcher | Apertura de URLs externas |

---

## Estructura del proyecto

```text
frontend/lib/
├── core/
│   ├── api/
│   │   └── api_client.dart          # Dio singleton, URL base, interceptor JWT
│   ├── database/
│   │   ├── local_db.dart            # Exportación condicional web / nativo
│   │   ├── local_db_native.dart     # SQLite real (Linux / Android)
│   │   └── local_db_web.dart        # Stub sin operaciones (Web)
│   ├── sync/
│   │   ├── sync_service.dart        # Exportación condicional web / nativo
│   │   ├── sync_service_native.dart # Cola offline + retry automático
│   │   └── sync_service_web.dart    # Stub (online = true siempre)
│   ├── permissions.dart             # Constantes Perm.xxxx
│   └── theme/
│       └── colors.dart              # Paleta: kPrimary, kDanger, kSuccess…
├── models/
│   └── insumo_model.dart
├── providers/
│   ├── auth_provider.dart           # JWT, usuario, permisos
│   └── inventario_provider.dart     # Lista de insumos con caché
└── screens/
    ├── login_screen.dart
    ├── main_shell.dart              # Navegación: tabs compactos (desktop) / drawer (móvil)
    ├── dashboard_screen.dart        # Estadísticas en tiempo real + tabla de críticos
    ├── inventario_screen.dart       # Tabla con filtros por tipo de insumo
    ├── insumo_detail_screen.dart    # Detalle, foto, SGA, últimos movimientos
    ├── insumo_form_screen.dart      # Crear / editar insumo
    ├── sga_screen.dart              # Ficha SGA: ver / editar / Colmena ARL / PDF
    ├── movimientos_screen.dart      # Préstamos y devoluciones
    ├── bitacora_screen.dart         # Historial de movimientos con filtros
    ├── horario_screen.dart          # Cuadrícula Lun–Sáb × 6–21h con celdas fusionadas
    ├── configuracion_screen.dart    # Ubicaciones y unidades de medida (CRUD)
    ├── permisos_screen.dart         # Permisos por rol + cambio de rol
    ├── solicitud_prestamo_screen.dart   # Formulario público (sin login) — QR Préstamo
    ├── registro_horas_screen.dart       # Formulario público — QR Registro de horas monitor
    ├── registro_practica_screen.dart    # Formulario público — QR Registro de práctica
    └── reporte_rotura_screen.dart       # Formulario público — QR Reporte de rotura
```

---

## Módulos principales

### Inventario

Gestión completa de insumos del laboratorio (Implementos, Vidriería, Químicos, Equipos). Incluye semáforo de stock (🔴 crítico / 🟡 bajo / 🟢 normal), foto por URL, y navegación al detalle del insumo.

### SGA / GHS

Ficha de seguridad química: pictogramas GHS01–GHS09, rombo NFPA 704, frases H/P, datos de composición, primeros auxilios y transporte. Extracción automática desde PDF de FDS usando Google Gemini. Genera etiqueta GHS en PDF y ficha Colmena ARL.

### Préstamos y Movimientos

Flujo completo: solicitud → aprobación (con descuento de stock) → devolución (con reintegro de stock). Bitácora de todos los movimientos (ENTRADA, SALIDA, AJUSTE, ROTURA, CONSUMO_PRACTICA).

### Horario Semanal

Cuadrícula visual Lunes–Sábado × 6:00–21:00h. Dos vistas: **Encargados** (quién está de turno) y **Asignaturas** (qué práctica se realiza). Soporta fusión automática de bloques consecutivos de la misma asignatura.

### Formularios Públicos (QR)

Cuatro formularios sin login, accesibles desde códigos QR generados en el Dashboard:

| Formulario | Ruta |
| --- | --- |
| Solicitud de Préstamo | `/solicitud` |
| Registro de Horas Monitor | `/registro-horas` |
| Registro de Práctica | `/registro-practica` |
| Reporte de Rotura | `/reporte-rotura` |

### Sistema de Permisos

Los permisos se cargan al autenticar desde `/api/usuarios/mis-permisos/`. La UI muestra u oculta tabs y botones según `auth.can(Perm.xxxx)`.

| Permiso | Descripción |
| --- | --- |
| `inventario.ver` | Ver listado de inventario |
| `inventario.gestionar` | Crear / editar / eliminar insumos |
| `prestamos.ver` | Ver préstamos |
| `prestamos.gestionar` | Aprobar / rechazar / devolver |
| `bitacora.ver` | Ver bitácora |
| `academico.ver` | Ver horario semanal |
| `academico.gestionar` | Editar horario (solo ADMIN y LAB) |
| `configuracion.gestion` | Acceder a Configuración |
| `configuracion.roles` | Gestionar permisos de roles |

### Modo Offline

En plataformas nativas (Linux/Android), las operaciones de escritura fallidas se encolan en SQLite local y se reintenta el envío al recuperar conexión. El indicador de red en la AppBar muestra el estado y los pendientes.

---

## Configuración y ejecución

### Prerequisitos

- Flutter SDK `^3.x` con Dart `^3.11`
- Backend corriendo en `http://localhost:8000` (ver repositorio Backend)

### URL base de la API

Se configura en [frontend/lib/core/api/api_client.dart](frontend/lib/core/api/api_client.dart). En desarrollo apunta a `http://localhost:8000/api/`.

### Correr en Linux (desarrollo)

```bash
cd frontend
flutter pub get
flutter run -d linux
```

### Correr en Web

```bash
flutter run -d chrome
```

### Build Android (release)

```bash
flutter build apk --release
# El APK queda en build/app/outputs/flutter-apk/app-release.apk
```

### Build Web (para servir con nginx)

```bash
flutter build web
# Los archivos quedan en build/web/
# Copiar a la ruta configurada en nginx.conf del backend
```

### Análisis estático

```bash
flutter analyze
```

---

## Plataformas soportadas

| Plataforma | Estado |
| --- | --- |
| Linux desktop | Primaria de desarrollo |
| Android | Soportado (build APK) |
| Web | Soportado (nginx en Docker) |

---

## Repositorios relacionados

- **Backend (Django)**: [SGI_LAB_MANAGER_BACKEND](https://github.com/FoxyYTs/SGI_LAB_MANAGER_BACKEND)
