# Changelog

Cambios de SGI LAB MANAGER (app y backend). Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versiones según
[SemVer](https://semver.org/lang/es/).

## [1.1.0] — 2026-10-30

### Añadido
- **Impresiones 3D**: cotización para clientes externos por gramos de material
  y horas de máquina (redondeo a la centena, cobro mínimo y margen por fallos
  editables), varios materiales, registro de pago con número de recibo.
  Permisos `impresiones.ver`, `impresiones.gestionar` (MONITOR y LAB) e
  `impresiones.tarifas` (LAB).
- Autorización del cliente para guardar su documento y contacto (Ley 1581).
- **Modo oscuro** con selector Sistema/Claro/Oscuro.

### Cambiado
- Política de privacidad: el PCJIC es el responsable del tratamiento; se
  declaran los datos de impresiones 3D y los encargados Firebase y Google
  Analytics. La versión de la app coincide con la publicada en la web.
- Los permisos se refrescan al abrir la app (antes solo al iniciar sesión o
  volver a primer plano).

### Seguridad
- Sin auto-escalada de permisos con `configuracion.roles`.
- Los permisos individuales se revocan al pasar a ESTUDIANTE o desactivar.
- Cambiar el propio correo exige la contraseña actual.
- El registro ya no revela si un correo o documento existen; el listado
  público de docentes ya no expone correos.
- Cabeceras de seguridad en la web (HSTS, X-Frame-Options, Referrer-Policy,
  CSP en modo reporte).
- Android: sin copias de seguridad ni transferencia de datos de la app.
- Dependencias del servidor con parches de octubre 2026 (Django 5.2.18,
  DRF 3.18.3, Pillow 13.0.0, pypdf 6.21.4, certifi, nginx 1.31.8,
  PostgreSQL 15.19).

### Accesibilidad
- Nombre accesible (tooltip) en los botones de solo ícono y área táctil
  mínima en Horario; avisos de caché y sin conexión legibles en modo oscuro.

## [1.0.6] — 2026-10-09
- Inventario de residuos, etiquetas en Word, horarios por rangos y revisión
  de octubre. Ver las notas de la versión en GitHub.
