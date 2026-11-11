# Changelog

Cambios de SGI LAB MANAGER (app y backend). Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versiones según
[SemVer](https://semver.org/lang/es/).

## [1.2.0] — 2026-11-10

### Añadido
- **Impresiones 3D por encargo**: un encargo tiene varias piezas, cada una
  con su material; el redondeo y el cobro mínimo se aplican al encargo.
- **Abonos**: pagos parciales con recibo y quién los recibió; el encargo
  queda Pendiente, Abonado o Pagado y muestra el saldo. Un abono equivocado
  se anula con motivo (permiso nuevo `impresiones.anular_pagos`, LAB).
- **Estado del trabajo**: Cotizado, En impresión, Listo para recoger y
  Entregado.
- **QR de seguimiento**: página pública con el nombre abreviado del
  cliente, piezas, pagos y estado; sin documento ni contacto. El código se
  puede regenerar.
- Tarifas nuevas: cargo de preparación por pieza, recargo por urgencia y
  anticipo sugerido (por defecto 0, 15 % y 50 %).
- **Enlace al archivo de cada pieza** (Drive, OneDrive, Printables…): el
  modelo 3D queda fuera del servidor. Solo lo ve el personal; no sale en el
  QR.

### Cambiado
- nginx acepta hasta 50 MB por petición en `/api/` (antes 10 MB): los
  informes PDF admiten 50 MB y la API pasa por nginx.
- Las fuentes .otf/.ttf ya no se guardan en la caché de Cloudflare: la de
  íconos no lleva hash en el nombre y salían íconos en blanco.
- "Marcar pagado" se reemplaza por "Registrar abono". La API cambió: la
  versión 1.1.0 de la app ya no puede cotizar ni cobrar impresiones.
- Política de privacidad vigente desde el 10 de noviembre de 2026 (web y
  app): declara la página pública del QR, los abonos, los enlaces a
  archivos en servicios externos y quién registra la autorización.
- Entregar un encargo con saldo pendiente pide confirmación (DEF-051).

### Corregido
- Un encargo con abonos ya no se puede editar ni borrar (DEF-036, DEF-037).
- Horas de impresión absurdas devuelven un error claro y no un 500 (DEF-045).
- La fecha de autorización de datos ya no se edita desde Django admin
  (DEF-042).
- La autorización de datos (Ley 1581) vale solo para ese nombre, documento
  y contacto: si cambian, se pide de nuevo; sin documento ni contacto no se
  guarda; queda quién la registró (DEF-038 a DEF-041).
- La casilla de autorización oculta ya no envía su valor y su error
  desaparece al marcarla (DEF-043, DEF-044).
- Un encargo que tuvo abonos, aunque estén anulados, ya no se borra: se
  perdía el rastro del dinero recibido (DEF-046).
- Gramos o tarifas absurdos devuelven un error claro y no un 500 (DEF-048).
- Anular un abono a la vez que se registra otro ya no deja mal el estado
  de pago (DEF-049), y las acciones con filtros en la URL ya no dan 500
  (DEF-050).

### Seguridad
- Google Analytics recibía la URL completa: el código del QR y el token y
  correo del enlace de restablecer contraseña. Ahora se envía sin
  parámetros (DEF-047).
- Editar o borrar un encargo bloquea la fila mientras revisa sus abonos,
  para que un abono simultáneo no se cuele.

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
