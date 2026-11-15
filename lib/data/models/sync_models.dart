/// Modelos de la sincronización (Sprint 2). Son de solo lectura: la app no
/// inventa resultados del servidor.
library;

/// Resumen de una subida de la cola local.
class SyncPushSummary {
  const SyncPushSummary({
    this.confirmadas = 0,
    this.enRevision = 0,
    this.rechazadas = 0,
    this.diferidas = 0,
  });

  /// Operaciones que el servidor aplicó (alta, corrección o reenvío idempotente).
  final int confirmadas;

  /// Operaciones que quedaron en «revisar» (las decide el agrónomo desde la bandeja).
  final int enRevision;

  /// Operaciones rechazadas por una regla de negocio o por conflicto de contenido.
  final int rechazadas;

  /// Registros que todavía no se pueden enviar (p. ej. una lectura sin visita).
  final int diferidas;

  int get enviadas => confirmadas + enRevision + rechazadas;
  bool get hayPendientes => enRevision > 0 || rechazadas > 0 || diferidas > 0;
}

/// Operación del servidor que espera una decisión humana (`revisar`) o que fue rechazada.
class ServerOperation {
  const ServerOperation({
    required this.operId,
    required this.entidad,
    required this.accion,
    required this.registroId,
    required this.version,
    required this.clasificacion,
    required this.capturadaEn,
    required this.recibidaEn,
    this.motivo,
  });

  factory ServerOperation.fromJson(Map<String, dynamic> j) => ServerOperation(
        operId: (j['oper_id'] as num).toInt(),
        entidad: j['entidad']?.toString() ?? '',
        accion: j['accion']?.toString() ?? '',
        registroId: j['registro_id']?.toString() ?? '',
        version: (j['version'] as num?)?.toInt() ?? 1,
        clasificacion: j['clasificacion']?.toString() ?? 'revisar',
        motivo: j['motivo'] as String?,
        capturadaEn: _fecha(j['t_captura']),
        recibidaEn: _fecha(j['t_recepcion']),
      );

  final int operId;
  final String entidad;
  final String accion;
  final String registroId;
  final int version;
  final String clasificacion; // revisar | rechazada
  final String? motivo;
  final DateTime capturadaEn;
  final DateTime recibidaEn;

  bool get esVisita => entidad == 'visita';
  bool get enRevision => clasificacion == 'revisar';

  String get titulo => switch ((entidad, accion)) {
        ('visita', _) => 'Visita de campo',
        ('lectura_trampa', 'anular') => 'Anulación de lectura',
        ('lectura_trampa', 'corregir') => 'Corrección de lectura',
        ('lectura_trampa', _) => 'Lectura de trampa',
        _ => entidad,
      };

  String get estado => enRevision ? 'Por revisar' : 'Rechazada';

  ServerOperation copyWith({String? clasificacion, String? motivo}) =>
      ServerOperation(
        operId: operId,
        entidad: entidad,
        accion: accion,
        registroId: registroId,
        version: version,
        clasificacion: clasificacion ?? this.clasificacion,
        motivo: motivo ?? this.motivo,
        capturadaEn: capturadaEn,
        recibidaEn: recibidaEn,
      );
}

/// Un cambio que el servidor anuncia para que el móvil refresque su copia local.
class ServerChange {
  const ServerChange({
    required this.tipo,
    required this.id,
    required this.accion,
    required this.instante,
  });

  factory ServerChange.fromJson(Map<String, dynamic> j) => ServerChange(
        tipo: j['tipo']?.toString() ?? '',
        id: j['id']?.toString() ?? '',
        accion: j['accion']?.toString() ?? '',
        instante: _fecha(j['t']),
      );

  final String tipo; // planificacion | notificacion | paquete_campo | …
  final String id;
  final String accion; // creado | actualizado | invalidado
  final DateTime instante;
}

/// Página de la bajada de cambios (`GET /sincronizacion/cambios`).
class SyncChanges {
  const SyncChanges({
    required this.cursor,
    required this.servidorUtc,
    required this.cambios,
    required this.hayMas,
  });

  static const vacio = SyncChanges(
    cursor: '',
    servidorUtc: null,
    cambios: [],
    hayMas: false,
  );

  final String cursor;
  final DateTime? servidorUtc;
  final List<ServerChange> cambios;
  final bool hayMas;

  factory SyncChanges.fromJson(Map<String, dynamic> j) => SyncChanges(
        cursor: j['cursor']?.toString() ?? '',
        servidorUtc:
            j['servidor_utc'] == null ? null : _fecha(j['servidor_utc']),
        cambios: [
          for (final c in (j['cambios'] as List? ?? const []))
            if (c is Map) ServerChange.fromJson(Map<String, dynamic>.from(c)),
        ],
        hayMas: j['hay_mas'] as bool? ?? false,
      );
}

DateTime _fecha(dynamic v) => v == null
    ? DateTime.now()
    : DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();
