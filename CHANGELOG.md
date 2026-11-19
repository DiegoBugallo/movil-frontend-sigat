# Cambios del móvil (app SIGAT Durazno)

Registro de los cambios de la app Flutter. Una entrada por PR, la más reciente arriba.
El diff, las pruebas y las capturas viven en GitHub; aquí queda el **por qué** y lo que
cambió, para no tener que reconstruirlo desde el historial.

## 2026-11-18 · Sincronización del técnico (Sprint 2)

Rama `feature/sprint2-sincronizacion` · 20 archivos de código (+1349 / −167) más este registro.

### Qué cambió

- **Envío por lote** (`POST /api/v1/sincronizacion/lotes`): visitas, lecturas y
  justificaciones guardadas en el teléfono, en tandas de hasta 200. La visita va antes que
  sus lecturas y cada operación lleva un `cliente_id` estable derivado del dispositivo y
  del registro.
- **Bandeja de solo lectura** (`GET /api/v1/sincronizacion/operaciones`): muestra
  clasificación, motivo y datos de cada operación recibida. No tiene botones de decisión
  porque el backend no expone la resolución en este sprint.
- **Huella canónica** (`lib/core/utils/canonical_json.dart`): JSON determinista (claves
  ordenadas, números y cadenas como RFC 8785) y SHA-256 del sobre, para que el teléfono y
  el servidor calculen el mismo `hash_contenido`.
- **Resultado por operación** (`lib/data/models/sync_models.dart`): el resumen separa
  confirmadas, en revisión, rechazadas y diferidas. Solo se borra de la cola lo que el
  servidor confirmó; lo demás queda con el motivo.
- **Fecha real de observación**: `t_observacion` sale de `observedAt`, no del momento del
  envío; `t_captura` usa el mayor entre el reloj actual y la observación.
- **Lectura leída / no leída**: una trampa no leída envía `lect_leida = false`, sin
  especímenes y con justificación; una leída con 0 es «cero moscas».
- **Sin rutas inventadas**: se quitaron las llamadas a `/operaciones/{id}/resolucion` y
  `/cambios`, que el backend no expone (501) y quedan fuera del alcance.
- **Dependencia nueva**: `crypto` (SHA-256). Los vectores de huella se movieron al código;
  `test/vectores_huella.json` queda en `.gitignore` por ser generado.

### Por qué

- Hasta ahora el técnico registraba sin conexión y nada salía del teléfono: las rutas del
  contrato respondían 501. El backend del Sprint 2 ya recibe y consulta; la app se conecta
  a esas dos rutas reales.
- La idempotencia importa en campo: si se corta la red a mitad de un envío, reintentar no
  duplica registros y la app puede mostrar qué guardó el servidor.
- La bandeja es de solo lectura a propósito: sin `resolucion` en el backend, ofrecer
  botones de aceptar o descartar sería una acción que no se puede cumplir.

### Pruebas

- `flutter test`: 140 en verde, incluidas 8 nuevas de JSON canónico y las de envío,
  idempotencia, lectura sin visita y bandeja.
- `test/support/backend_de_prueba.dart`: doble del backend con las dos rutas nuevas.
- `flutter analyze`: sin errores; 102 avisos de deprecación de `material.dart` que ya
  venían de `develop`.
- `dart format --set-exit-if-changed lib test`: 0 cambios.

### Nota de integración

- Este PR necesita el de formato. Hasta que ese se fusione, GitHub muestra también sus 152
  archivos; después el diff baja a estos 21.

## 2026-11-07 · Formato de `lib` y `test`

Rama `fix/tecnico-formato-analisis` · 152 archivos (+3859 / −1800), un commit.

### Qué cambió

- `dart format` aplicado de una vez: 135 archivos de `lib/` y 17 de `test/`.
- Llaves en los `if` de una línea, como exige `curly_braces_in_flow_control_structures`.
- Único cambio no mecánico: el comentario de la tabla de estado de la API separa lo que
  funciona de lo que aún responde 501.
- Sin cambios de lógica, rutas ni textos visibles.

### Por qué

- El CI ejecuta `dart format --output=none --set-exit-if-changed lib test` y `develop` no
  lo pasaba: 152 de 163 archivos estaban fuera de formato desde el 30/10. Cualquier PR
  quedaba en rojo, aunque no tocara formato.
- Se separó en su propio PR para que el revisor vea que es mecánico y para que el PR del
  sprint muestre solo su diff.

### Pruebas

- `flutter test`: 140 en verde (no hay código nuevo).
- `flutter analyze`: sin errores; los 102 avisos de deprecación ya estaban en `develop`.
- `dart format --set-exit-if-changed`: 0 cambios después del commit.

Criterio de revisión: un archivo que no sea reacomodo de líneas o llaves no pertenece a
ese PR.
