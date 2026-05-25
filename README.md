# SGI LAB MANAGER — Frontend

Sistema de Gestión de Inventarios para laboratorio académico. Aplicación multi-plataforma desarrollada en **Flutter**, que corre en Windows, Android y Web.

> Proyecto desarrollado como solución integral para la administración de inventario, préstamos de equipos e insumos, seguridad química (SGA/GHS) y gestión académica de un laboratorio integrado.

---

## Tecnologías

| Tecnología | Rol |
| --- | --- |
| Flutter / Dart | Framework UI multi-plataforma |
| Provider | Gestión de estado reactivo |
| Dio | Cliente HTTP con interceptor JWT |
| sqflite + sqflite_common_ffi | Persistencia local (SQLite) para modo offline |
| connectivity_plus | Detección de red y sincronización |
| qr_flutter | Generación de códigos QR |
| flutter_secure_storage | Almacenamiento seguro de tokens |
| file_picker | Selección de PDFs (fichas de seguridad) |

---

## Funcionalidades principales

### Gestión de inventario

Control completo de insumos del laboratorio (Implementos, Vidriería, Químicos, Equipos). Incluye semáforo de stock visual (crítico / bajo / normal), registro de foto por URL y acceso al detalle completo de cada insumo.

### Seguridad química — SGA / GHS

Ficha de seguridad química por insumo: pictogramas GHS, rombo NFPA 704, frases de peligro y precaución, composición, primeros auxilios y datos de transporte. **Extracción automática de datos desde PDF** de Ficha de Datos de Seguridad usando inteligencia artificial (Google Gemini). Generación de etiqueta GHS en PDF y ficha para reporte Colmena ARL.

### Préstamos y movimientos

Flujo de préstamo con estados (Pendiente → Activo → Devuelto), con descuento y reintegro automático de stock. Bitácora completa de todos los movimientos del inventario.

### Horario semanal

Cuadrícula visual Lunes–Sábado × 6:00–21:00h con dos vistas: encargados de turno y asignaturas en práctica. Soporta fusión automática de bloques consecutivos de la misma materia.

### Formularios públicos via QR

Cuatro formularios accesibles sin login, cada uno con su propio código QR: solicitud de préstamo, registro de horas de monitor (con descripción de actividades y duración), registro de práctica docente (selección de docente, asignatura, guía, horario de ingreso/salida) y reporte de implemento roto. Los formularios de práctica y horas soportan catálogos precargados para agilizar el llenado.

### Generación de informes en PDF

Pantalla de informes con seis tipos de reporte: inventario completo, préstamos, bitácora de movimientos, horas de monitor, prácticas docentes y deudores morosos. Cada informe admite filtros de fecha y queda registrado en auditoría.

### Perfil de usuario

Pantalla de perfil que permite al usuario autenticado ver y editar sus datos personales (nombre, identificación, teléfono) directamente desde la aplicación.

### Gestión de catálogos académicos

Pantalla de configuración con cinco pestañas: ubicaciones, unidades de medida, programas académicos, docentes (con asignación múltiple a programas y asignaturas) y guías de práctica (con gestión de insumos requeridos y apertura de PDF externo).

### Sistema de permisos por rol

Roles diferenciados (Administrador, Laboratorista, Monitor, Docente, Estudiante). La interfaz adapta dinámicamente las opciones visibles según los permisos del usuario autenticado. Pantalla de administración de permisos por rol con cambio de rol en tiempo real.

### Modo offline

En plataformas de escritorio y móvil, el inventario se cachea en SQLite local. Las operaciones fallidas por falta de red se encolan y se sincronizan automáticamente al recuperar la conexión.

---

## Arquitectura del código

```text
frontend/lib/
├── core/           # API client, base de datos local, sync offline, permisos, tema
├── models/         # Modelos de datos Dart
├── providers/      # Estado global (auth, inventario)
└── screens/        # Pantallas de la aplicación
```

La exportación condicional (`dart.library.io` vs `dart.library.js_interop`) permite que las funciones de base de datos local y conectividad usen implementaciones reales en Windows/Android y stubs en Web, sin cambios en el resto del código.

---

## Plataformas

| Plataforma | Estado |
| --- | --- |
| Windows | Objetivo principal de producción |
| Android | Soportado — build APK |
| Web | Soportado — servido con nginx |
| Linux | Entorno de desarrollo |

---

## Cómo ejecutar

### Prerequisitos

- Flutter SDK `^3.x` con Dart `^3.11`
- Backend de la aplicación corriendo localmente

### Windows / Linux (escritorio)

```bash
cd frontend
flutter pub get
flutter run -d windows   # o -d linux en entorno de desarrollo
```

### Web

```bash
flutter run -d chrome
```

### Build Android

```bash
flutter build apk --release
```

### Build Web

```bash
flutter build web
```

---

## Repositorios relacionados

- **Backend (Django REST Framework + PostgreSQL)**: [SGI_LAB_MANAGER_BACKEND](https://github.com/FoxyYTs/SGI_LAB_MANAGER_BACKEND)
