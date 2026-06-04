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
| flutter_secure_storage | Almacenamiento seguro de tokens y foto de perfil |
| qr_flutter | Generación de códigos QR |
| file_picker | Selección de archivos (PDFs de FDS, fotos de perfil) |
| url_launcher | Apertura de enlaces externos (FDS en Drive, guías) |

---

## Funcionalidades

### Inventario

Control de insumos (Implemento, Vidriería, Químico, Equipo) con semáforo visual de stock, búsqueda con debounce de 300ms y filtros por tipo. Cada insumo puede tener múltiples **presentaciones** con stock, unidad de medida y foto propios. Vista tabla en desktop y cards en móvil.

### SGA / Seguridad Química

Ficha completa GHS organizada en tres pestañas:

- **Datos SGA** — banner PELIGRO/ATENCIÓN, pictogramas GHS01–GHS09, rombo NFPA 704, frases H/P con código destacado, EPP y primeros auxilios.
- **Editar** — formulario por secciones (S1–S14) agrupadas en cards con header de color.
- **Colmena ARL** — acordeones S1–S14 para copiar datos al software de Colmena ARL.

Extracción automática desde PDF de FDS con IA (**Groq/Llama**): flujo en 2 pasos — previsualización con diff de cambios y campos sin datos, confirmación sin re-procesar el PDF. Generación de etiqueta GHS en PDF.

### Préstamos y Movimientos

Flujo completo: PENDIENTE → ACTIVO (con descuento de stock validado) → DEVUELTO. Bitácora de movimientos con filtros. Cola offline para aprobaciones y rechazos sin red.

### Horario Semanal

Cuadrícula Lun–Sáb × 6–21h. Vista de encargados y asignaturas. Re-fetch automático al recuperar conexión.

### Dashboard

Stats en tiempo real (insumos críticos/bajos, préstamos activos/pendientes). Horario semanal resumido (65% del ancho) + acciones rápidas con botón de Códigos QR prominente y grid 2×3 (35%). Tabla de insumos críticos al fondo.

### Informes

Seis tipos de informe en PDF y Excel: inventario, préstamos, bitácora, horas monitor, prácticas docentes, deudores morosos. Filtros de fecha. Auditoría en `RegistroInforme`.

### Formularios Públicos QR

Cuatro formularios sin login, responsivos (card centrado en desktop ≥700px, columna en móvil):

- **Solicitud de préstamo** — accesible desde QR sin cuenta
- **Registro de horas monitor** — check-in con duración y actividades
- **Registro de práctica docente** — QR apunta a Google Forms externo
- **Reporte de rotura** — con selección de insumo y fecha

### Mi Perfil

Edición de nombre, email, teléfono, semestre, programa. Subida de foto de perfil (multipart). Cambio de contraseña con verificación de la actual. El avatar del topbar se actualiza en tiempo real tras subir foto.

### Configuración (8 tabs)

| Tab | Contenido |
| --- | --- |
| Ubicaciones | CRUD de ubicaciones del laboratorio |
| Unidades | CRUD de unidades de medida |
| Programas | CRUD de programas académicos |
| Docentes | CRUD con relaciones M2M a programas y asignaturas |
| Guías | CRUD de guías de práctica + gestión de insumos requeridos |
| Áreas | CRUD de áreas académicas |
| Asignaturas | CRUD con dropdown de área |
| Laboratorio | Datos del lab y proveedor por defecto (etiquetas SGA) |

### Gestión de Permisos

Roles diferenciados (ADMIN, LAB, MONITOR, ESTUDIANTE). Permisos por rol y permisos extra individuales activos en tiempo real sin relogin. Búsqueda de usuarios en tiempo real. Toggle de activación/desactivación.

### Modo Offline (Android / Linux)

Inventario, Dashboard, Bitácora y Movimientos cachean en SQLite. Al recuperar red, se dispara re-fetch automático en segundo plano. Cola de operaciones pendientes (aprobar/rechazar préstamos) que se ejecutan al reconectar. Login bloqueado sin red.

---

## Notificaciones Background (solo Android)

Tres tareas periódicas gestionadas por **WorkManager**:

| Tarea | Frecuencia | Descripción |
| --- | --- | --- |
| `sgi_stock_check` | 6 horas | Alerta si hay insumos con stock crítico |
| `sgi_schedule_check` | 15 min | Recordatorio de fin de turno y práctica próxima |
| `sgi_server_monitor` | 15 min | Notifica cuando el servidor cae o se recupera |

Cada notificación se dispara una sola vez por evento. Las tareas se cancelan al cerrar sesión.

---

## Seguridad y sesión

- Token JWT access: 2 horas. Token refresh: 7 días.
- Logout invalida el refresh token en el servidor (blacklist JWT).
- `flutter_secure_storage` almacena tokens, rol, permisos y foto de perfil.
- La sesión persiste entre reinicios de la app (sin internet incluido).
- En **web**, la sesión expira a medianoche del día de login.
- Los clientes Android/Linux envían `X-App-Version` — si la versión es menor a la mínima configurada en servidor, la app muestra pantalla de actualización obligatoria (HTTP 426).

---

## Plataformas

| Plataforma | Estado | Comando |
| --- | --- | --- |
| Android | Producción | `flutter build apk --release --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io` |
| Web | Producción | `flutter build web --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io --release` |
| Linux | Desarrollo | `flutter run -d linux --dart-define=SERVER_URL=http://localhost:8000` |

### APK de diagnóstico

```bash
flutter build apk --release \
  --dart-define=DEV_MODE=true \
  --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io
```

`DEV_MODE=true` habilita log a archivo y muestra detalles técnicos en mensajes de error.

---

## Arquitectura del código

```text
frontend/lib/
├── core/
│   ├── api/            api_client.dart — Dio singleton, URL base, interceptor JWT
│   ├── cache/          cache_service.dart — caché SQLite genérico (json_cache)
│   ├── database/       local_db.dart — SQLite nativo vs stub web
│   ├── sync/           sync_service.dart — cola offline y reconexión
│   ├── permissions.dart
│   └── theme/colors.dart
├── models/
│   └── insumo_model.dart
├── providers/
│   ├── auth_provider.dart        sesión, permisos, foto de perfil
│   └── inventario_provider.dart
├── screens/                      una pantalla por módulo
├── services/
│   ├── background_tasks.dart     WorkManager (Android only)
│   └── notification_service.dart
└── widgets/
    └── qr_generator_dialog.dart
```

La exportación condicional (`dart.library.io` vs `dart.library.js_interop`) permite que SQLite y connectivity usen implementaciones reales en Linux/Android y stubs no-op en Web.
