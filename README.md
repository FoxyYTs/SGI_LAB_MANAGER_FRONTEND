# SGI LAB MANAGER — Frontend

Aplicación multi-plataforma en **Flutter** para la gestión del laboratorio integrado del PCJIC Rionegro, Colombia. Corre en Android, Web y Linux (desarrollo).

---

## Stack tecnológico

| Tecnología | Rol |
| --- | --- |
| Flutter / Dart | Framework UI multi-plataforma |
| Provider | Gestión de estado reactivo |
| Dio | Cliente HTTP con interceptor JWT |
| sqflite + sqflite_common_ffi | SQLite local (modo offline — Android/Linux) |
| connectivity_plus | Detección de red y sincronización automática |
| workmanager | Tareas periódicas en background (solo Android) |
| flutter_local_notifications | Notificaciones nativas Android |
| shared_preferences | Estado persistente para tareas de fondo |
| flutter_secure_storage | Almacenamiento seguro de tokens y foto de perfil |
| qr_flutter | Generación de códigos QR |
| file_picker | Selección de archivos (PDFs de FDS, fotos de perfil) |

---

## Funcionalidades

### Inventario

Control de insumos (Implemento, Vidriería, Químico, Equipo) con semáforo visual de stock, búsqueda con debounce de 300ms, filtros por tipo, tabla desktop y cards en móvil.

### SGA / Seguridad Química

Ficha completa GHS: pictogramas GHS01–GHS09, NFPA 704, frases H/P, composición, datos de transporte. Extracción automática desde PDF de FDS usando Google Gemini. Generación de etiqueta GHS y ficha Colmena ARL en PDF.

### Préstamos y Movimientos

Flujo completo: PENDIENTE → ACTIVO (con descuento de stock validado) → DEVUELTO. Bitácora de movimientos con filtros. Cola offline para aprobaciones y rechazos sin red.

### Horario Semanal

Cuadrícula Lun–Sáb × 6–21h. Vista de encargados y asignaturas con fusión automática de bloques consecutivos. Re-fetch automático al recuperar conexión.

### Informes

Seis tipos de informe en PDF y Excel: inventario, préstamos, bitácora, horas monitor, prácticas docentes, deudores morosos. Filtros de fecha. Auditoría en `RegistroInforme`.

### Formularios Públicos QR

Cuatro formularios sin login, rediseñados responsivos (card centrado en desktop ≥700px, columna en móvil):

- **Solicitud de préstamo** — accesible desde QR sin cuenta
- **Registro de horas monitor** — check-in con duración y actividades
- **Registro de práctica docente** — QR apunta a Google Forms externo
- **Reporte de rotura** — con selección de insumo y fecha

### Mi Perfil

Edición de nombre, email, teléfono, semestre, programa. Subida de foto de perfil (multipart). **Cambio de contraseña** con verificación de la actual. El avatar del topbar se actualiza en tiempo real tras subir foto.

### Gestión de Permisos

Roles diferenciados (ADMIN, LAB, MONITOR, ESTUDIANTE). Permisos por rol y permisos extra individuales activos en tiempo real sin relogin. Búsqueda de usuarios en tiempo real. Toggle de activación/desactivación.

### Modo Offline (Android / Linux)

Inventario y Dashboard cachean en SQLite. Al recuperar red, se dispara re-fetch automático en segundo plano. Cola de operaciones pendientes (aprobar/rechazar préstamos) que se ejecutan al reconectar.

---

## Notificaciones Background (solo Android)

Tres tareas periódicas gestionadas por **WorkManager** (no disponibles en Linux/Web):

| Tarea | Frecuencia | Descripción |
| --- | --- | --- |
| `sgi_stock_check` | 6 horas | Alerta si hay insumos con stock crítico |
| `sgi_schedule_check` | 15 min | Recordatorio de fin de turno y práctica próxima |
| `sgi_server_monitor` | 15 min | Notifica cuando el servidor cae o se recupera |

Cada notificación se dispara **una sola vez** por evento. Las tareas se cancelan automáticamente al cerrar sesión.

---

## Seguridad y sesión

- Token JWT access: 2 horas. Token refresh: 7 días.
- `flutter_secure_storage` almacena tokens, rol, permisos y foto de perfil.
- La sesión persiste entre reinicios de la app (sin internet incluido).
- En **web**, la sesión expira a medianoche del día de login.
- Los clientes Android/Linux envían `X-App-Version` — si la versión es menor a la mínima configurada en servidor, la app muestra pantalla de actualización obligatoria (HTTP 426).

---

## Plataformas

| Plataforma | Estado | Comando |
| --- | --- | --- |
| Android | Producción | `flutter build apk --release --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io` |
| Web | Producción | `flutter build web --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io --dart-define=FRONTEND_URL=https://sgilabmanager.foxyyts.qzz.io --release` |
| Linux | Desarrollo | `flutter run -d linux` |

### APK de diagnóstico

```bash
flutter build apk --release \
  --dart-define=DEV_MODE=true \
  --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io
```

---

## Arquitectura del código

```text
frontend/lib/
├── core/
│   ├── api/            api_client.dart — Dio singleton, URL base, interceptor JWT
│   ├── cache/          cache_service.dart — caché SQLite genérico
│   ├── database/       local_db.dart — SQLite nativo vs stub web
│   ├── sync/           sync_service.dart — cola offline y reconexión
│   ├── permissions.dart
│   └── theme/colors.dart
├── models/
│   └── insumo_model.dart
├── providers/
│   ├── auth_provider.dart      sesión, permisos, foto de perfil
│   └── inventario_provider.dart
├── screens/            una pantalla por módulo
├── services/
│   ├── background_tasks.dart   WorkManager (Android only)
│   └── notification_service.dart
└── widgets/
    └── qr_generator_dialog.dart
```

La exportación condicional (`dart.library.io` vs `dart.library.js_interop`) permite que SQLite y connectivity usen implementaciones reales en Linux/Android y stubs en Web.

---

## Repositorio relacionado

Backend (Django): [SGI_LAB_MANAGER_BACKEND](https://github.com/FoxyYTs/SGI_LAB_MANAGER_BACKEND)
