import 'package:flutter/foundation.dart';

import '../../data/app_services.dart';
import '../../data/connectivity_service.dart';
import '../../data/models/sync_models.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/field_repositories.dart';

enum SyncPhase { idle, syncing, done, error }

/// Sincronización en segundo plano, COMPARTIDA por todos los roles.
/// Cada usuario solo ve y envía sus propios registros (lo filtra el repositorio).
/// Sigue avanzando aunque el usuario cambie de pantalla.
class SyncController extends ChangeNotifier {
  SyncController._();
  static final instance = SyncController._();

  SyncPhase phase = SyncPhase.idle;
  List<SyncItem> items = [];

  /// Operaciones del servidor que esperan una decisión humana o fueron rechazadas.
  List<ServerOperation> inbox = [];
  SyncPushSummary? summary;
  int cambiosDescargados = 0;

  int syncedCount = 0;
  DateTime? lastSync;
  String? error;
  String? inboxError;
  bool loading = false;
  bool downloading = false;

  int get pendingCount => items.where((i) => !i.synced).length;
  bool get isSyncing => phase == SyncPhase.syncing;
  bool get hayRevisiones => inbox.isNotEmpty;

  Future<void> load() async {
    if (isSyncing) return;
    loading = true;
    notifyListeners();
    items = await AppServices.sync.getPending();
    lastSync = await AppServices.sync.lastSync();
    await _cargarBandeja();
    syncedCount = 0;
    phase = items.isEmpty && inbox.isEmpty ? SyncPhase.done : SyncPhase.idle;
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (isSyncing) return;
    // Verifica la conexión real justo antes de enviar.
    final online = await ConnectivityService.instance.refresh();
    if (!online) {
      phase = SyncPhase.error;
      error = 'Sin conexión. Los datos siguen guardados en el dispositivo.';
      notifyListeners();
      return;
    }

    phase = SyncPhase.syncing;
    error = null;
    summary = null;
    cambiosDescargados = 0;
    notifyListeners();

    try {
      final resumen = await AppServices.sync.push();
      final cambios = await AppServices.sync.pullChanges();
      summary = resumen;
      syncedCount = resumen.confirmadas;
      cambiosDescargados = cambios.cambios.length;
      await _cargarBandeja();
      items = await AppServices.sync.getPending();
      lastSync = await AppServices.sync.lastSync();
      phase = items.isEmpty && inbox.isEmpty ? SyncPhase.done : SyncPhase.idle;
      if (resumen.hayPendientes) {
        error = _resumenConPendientes(resumen);
      }
    } catch (e) {
      phase = SyncPhase.error;
      // El repositorio dice el motivo real (sin conexión, servidor no disponible…).
      error = e is DataException
          ? e.message
          : 'Se detuvo la sincronización. Tus datos siguen guardados en este teléfono: puedes reintentar.';
      items = await AppServices.sync.getPending();
      await _cargarBandeja();
    } finally {
      notifyListeners();
    }
  }

  /// Solo la bajada: no toca la cola de subida.
  Future<void> downloadChanges() async {
    if (isSyncing || downloading) return;
    final online = await ConnectivityService.instance.refresh();
    if (!online) {
      error = 'Sin conexión. No se pudieron descargar los cambios.';
      notifyListeners();
      return;
    }
    downloading = true;
    error = null;
    notifyListeners();
    try {
      final cambios = await AppServices.sync.pullChanges();
      cambiosDescargados = cambios.cambios.length;
    } catch (e) {
      error = e is DataException
          ? e.message
          : 'No se pudieron descargar los cambios.';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  /// Confirma o descarta una operación de la bandeja. Devuelve true si el servidor la aceptó.
  Future<bool> resolveOperation(
    ServerOperation operacion, {
    required bool confirmar,
    required String motivo,
  }) async {
    try {
      await AppServices.sync.resolveOperation(
        operacion.operId,
        confirmar: confirmar,
        motivo: motivo,
      );
      await _cargarBandeja();
      items = await AppServices.sync.getPending();
      lastSync = await AppServices.sync.lastSync();
      phase = items.isEmpty && inbox.isEmpty ? SyncPhase.done : SyncPhase.idle;
      notifyListeners();
      return true;
    } catch (e) {
      error = e is DataException
          ? e.message
          : 'No se pudo resolver la operación. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _cargarBandeja() async {
    try {
      inbox = await AppServices.sync.inbox();
      inboxError = null;
    } catch (e) {
      // Sin conexión la bandeja se conserva tal como estaba; no se inventan datos.
      inboxError =
          e is DataException ? e.message : 'No se pudo consultar la bandeja.';
    }
  }

  String _resumenConPendientes(SyncPushSummary resumen) {
    final partes = <String>[
      if (resumen.confirmadas > 0)
        '${resumen.confirmadas} ${resumen.confirmadas == 1 ? 'registro confirmado' : 'registros confirmados'}',
      if (resumen.enRevision > 0) '${resumen.enRevision} en revisión',
      if (resumen.rechazadas > 0) '${resumen.rechazadas} rechazados',
      if (resumen.diferidas > 0) '${resumen.diferidas} sin visita',
    ];
    return partes.isEmpty
        ? 'La sincronización terminó.'
        : '${partes.join(' · ')}. Revisa la bandeja del servidor.';
  }

  /// Al cerrar sesión: el siguiente usuario empieza con su propia cola.
  void reset() {
    phase = SyncPhase.idle;
    items = [];
    inbox = [];
    summary = null;
    cambiosDescargados = 0;
    syncedCount = 0;
    lastSync = null;
    error = null;
    inboxError = null;
    loading = false;
    downloading = false;
    notifyListeners();
  }
}
