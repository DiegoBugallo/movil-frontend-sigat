import '../models/lot.dart';
import '../models/reading.dart';
import '../models/sync_models.dart';
import '../models/trap.dart';
import '../models/visit.dart';

/// Contratos del trabajo de campo. La UI solo conoce estas interfaces; las
/// implementaciones contra el backend están en `api_repositories.dart` y se
/// registran en `lib/data/app_services.dart`.

/// Error controlado con mensaje para mostrar al usuario.
class DataException implements Exception {
  const DataException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// La ruta existe en el contrato del backend pero todavía no está programada (501).
/// La pantalla lo dice tal cual; nunca muestra datos inventados en su lugar.
class NotAvailableYet extends DataException {
  const NotAvailableYet(super.message);
}

/// No hay conexión con el servidor (o no respondió a tiempo).
class OfflineException extends DataException {
  const OfflineException(super.message);
}

abstract class LotsRepository {
  Future<List<Lot>> getAssignedLots(String userId);
  Future<Lot> getLot(String lotId);
  Future<List<Trap>> getTraps(String lotId);
  Future<void> updateLotStatus(String lotId, LotStatus status);
}

abstract class TrapsRepository {
  /// Busca por código ICA (QR o digitado). Devuelve null si no existe en el catálogo.
  Future<TrapLookup?> findByCode(String code, {String? activeLotId});
}

abstract class ReadingsRepository {
  /// Guarda la lectura en local (pendiente de sincronizar).
  Future<void> saveReading(Reading reading);

  /// Marca una trampa como no registrada con su motivo.
  Future<void> justifyTrap(
      {required String trapId,
      required String lotId,
      required String reason,
      String? visitId});

  Future<List<Reading>> readingsForLot(String lotId);

  /// Guarda la operación `visita` del lote en la cola local. Debe existir antes
  /// que sus lecturas; su id y contenido son fijos, así que reenviarla es idempotente.
  Future<void> saveFieldVisit({
    required String visiId,
    required String predioId,
    required String lotId,
    required DateTime startedAt,
    required String label,
  });
}

abstract class MapRepository {
  /// ¿El mosaico satelital del predio está descargado en el dispositivo?
  Future<bool> isMapDownloaded(String predioId);

  /// Descarga el mapa (requiere conexión). `onProgress` de 0 a 1.
  Future<void> downloadMap(String predioId,
      {void Function(double progress)? onProgress});
}

abstract class SyncRepository {
  /// Registros de la cola local que todavía no confirmó el servidor.
  Future<List<SyncItem>> getPending();

  /// Hora de la última sincronización confirmada por el servidor (si la hay).
  Future<DateTime?> lastSync();

  /// Sube todo lo pendiente en lotes de hasta 200 operaciones, con las visitas
  /// primero. La cola local queda actualizada con el resultado de cada operación.
  Future<SyncPushSummary> push();

  /// Operaciones del usuario en «revisar» o «rechazada» (bandeja del móvil).
  Future<List<ServerOperation>> inbox();

  /// Confirma o descarta una operación de la bandeja (R-T5).
  Future<void> resolveOperation(
    int operId, {
    required bool confirmar,
    required String motivo,
  });

  /// Baja los cambios del servidor desde el cursor guardado.
  Future<SyncChanges> pullChanges();
}

abstract class HistoryRepository {
  Future<List<VisitRecord>> getVisits();
  Future<void> saveVisit(VisitRecord visit);
}
