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

  /// Operaciones del servidor que quedaron en «revisar» o «rechazada».
  List<ServerOperation> inbox = [];
  SyncPushSummary? summary;

  int syncedCount = 0;
  DateTime? lastSync;
  String? error;
  String? inboxError;
  bool loading = false;

  int get pendingCount => items.where((i) => !i.synced).length;
  bool get isSyncing => phase == SyncPhase.syncing;

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
    notifyListeners();

    try {
      final resumen = await AppServices.sync.push();
      summary = resumen;
      syncedCount = resumen.confirmadas;
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
    if (partes.isEmpty) return 'La sincronización terminó.';
    return inbox.isEmpty
        ? '${partes.join(' · ')}.'
        : '${partes.join(' · ')}. Revisa la bandeja del servidor.';
  }

  /// Al cerrar sesión: el siguiente usuario empieza con su propia cola.
  void reset() {
    phase = SyncPhase.idle;
    items = [];
    inbox = [];
    summary = null;
    syncedCount = 0;
    lastSync = null;
    error = null;
    inboxError = null;
    loading = false;
    notifyListeners();
  }
}
