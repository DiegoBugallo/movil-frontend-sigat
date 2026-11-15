import 'package:flutter/material.dart';

import '../../app/shell_nav.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_services.dart';
import '../../data/models/sync_models.dart';
import 'sync_controller.dart';

/// M09-T — Sincronización: pendiente → sincronizando → todo actualizado.
/// También muestra la bandeja de operaciones en «revisar» o «rechazada» (R-T5).
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _sync = SyncController.instance;

  @override
  void initState() {
    super.initState();
    // Se carga después del primer frame: avisar a otros widgets durante el build no está permitido.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Sincronización'),
      body: ListenableBuilder(
        listenable: Listenable.merge([_sync, AppServices.isOnline]),
        builder: (context, _) {
          if (_sync.loading) return const AppLoader();
          final online = AppServices.isOnline.value;
          final total = _sync.items.length;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  children: [
                    ..._header(online, total),
                    if (_sync.summary != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _resumen(_sync.summary!),
                    ],
                    if (_sync.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AlertBanner(
                          type: AlertType.warning,
                          title: 'No se completó',
                          message: _sync.error),
                    ],
                    if (_sync.isSyncing)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                            'Puedes seguir usando la aplicación mientras se sincroniza.',
                            style: AppText.caption),
                      ),
                    if (_sync.items.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const FieldLabel('Pendientes en este teléfono'),
                      const SizedBox(height: 6),
                      for (final item in _sync.items) ...[
                        ChecklistTile(
                          title: item.label,
                          subtitle: item.lastError != null
                              ? 'Pendiente · ${item.lastError}'
                              : 'Pendiente · observación ${Fmt.dayMonth(item.observedAt)}, ${Fmt.time24(item.observedAt)}',
                          done: item.synced,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (_sync.inbox.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Expanded(
                              child: FieldLabel('Operaciones por revisar')),
                          StatusBadge('${_sync.inbox.length}',
                              tone: StatusTone.warning,
                              icon: Icons.rule_outlined),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'El servidor no aplicó estos registros todavía. Confírmalos o descártalos; '
                        'la decisión queda registrada con tu motivo.',
                        style: AppText.caption,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final op in _sync.inbox) ...[
                        _OperacionTile(
                          operacion: op,
                          onConfirmar: online
                              ? () => _resolver(op, confirmar: true)
                              : null,
                          onDescartar: online
                              ? () => _resolver(op, confirmar: false)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (_sync.inboxError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AlertBanner(
                          type: AlertType.info,
                          title: 'Bandeja del servidor',
                          message: _sync.inboxError),
                    ],
                    if (_sync.lastSync != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Última sincronización: ${Fmt.date(_sync.lastSync!)}, ${Fmt.time(_sync.lastSync!)}',
                          style: AppText.caption,
                        ),
                      ),
                  ],
                ),
              ),
              BottomActions(children: [
                if (_sync.phase == SyncPhase.done && _sync.inbox.isEmpty)
                  SecondaryButton(
                      label: 'Ir al inicio',
                      onPressed: () => ShellNav.goTo(context, AppTab.inicio))
                else
                  PrimaryButton(
                    label: _sync.phase == SyncPhase.error
                        ? 'Reintentar'
                        : 'Sincronizar',
                    loadingLabel: 'Sincronizando...',
                    isLoading: _sync.isSyncing,
                    color: AppColors.primaryDark,
                    onPressed: online ? _sync.syncAll : null,
                  ),
                if (online)
                  SecondaryButton(
                    label: 'Descargar cambios',
                    icon: Icons.cloud_download_outlined,
                    onPressed: _sync.downloading ? null : _sync.downloadChanges,
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resolver(ServerOperation op, {required bool confirmar}) async {
    final motivo = await showAppReasonDialog(
      context,
      title: confirmar ? 'Confirmar operación' : 'Descartar operación',
      message: confirmar
          ? 'El servidor aplicará «${op.titulo}» aunque una regla lo dejó en revisión. '
              'Explica por qué es correcto.'
          : '«${op.titulo}» no se aplicará en el servidor. Explica el motivo del descarte.',
      label: 'Motivo',
      confirmLabel: confirmar ? 'Confirmar' : 'Descartar',
      destructive: !confirmar,
    );
    if (motivo == null) return;
    final ok =
        await _sync.resolveOperation(op, confirmar: confirmar, motivo: motivo);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sync.error ?? 'No se pudo resolver.')),
      );
    }
  }

  List<Widget> _header(bool online, int total) {
    switch (_sync.phase) {
      case SyncPhase.syncing:
        return [
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge('Sincronizando...',
                tone: StatusTone.info, icon: Icons.sync),
          ),
          const SizedBox(height: 12),
          ProgressHeader(
            label: 'Sincronizando ${_sync.syncedCount} de $total...',
            value: total == 0 ? 0 : _sync.syncedCount / total,
          ),
        ];
      case SyncPhase.done:
        return const [
          Text('Todo está actualizado', style: AppText.h1),
          SizedBox(height: 6),
          Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge('Todo actualizado', icon: Icons.check)),
        ];
      case SyncPhase.idle:
      case SyncPhase.error:
        return [
          Text('${_sync.pendingCount} registros pendientes', style: AppText.h1),
          const SizedBox(height: 6),
          Align(
              alignment: Alignment.centerLeft,
              child: ConnectionChip(isOnline: online)),
          if (!online) ...[
            const SizedBox(height: 12),
            const AlertBanner(
              type: AlertType.info,
              title: 'Sin conexión',
              message:
                  'Los registros siguen guardados en el dispositivo. Sincroniza cuando tengas internet.',
            ),
          ],
        ];
    }
  }

  Widget _resumen(SyncPushSummary s) {
    final partes = <String>[
      if (s.confirmadas > 0) '${s.confirmadas} confirmadas',
      if (s.enRevision > 0) '${s.enRevision} por revisar',
      if (s.rechazadas > 0) '${s.rechazadas} rechazadas',
      if (s.diferidas > 0) '${s.diferidas} sin visita',
      if (_sync.cambiosDescargados > 0)
        '${_sync.cambiosDescargados} cambios descargados',
    ];
    return AppCard(
      tone: AppCardTone.highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resultado del último envío', style: AppText.bodySmStrong),
          const SizedBox(height: 4),
          Text(partes.isEmpty ? 'Nada que enviar.' : partes.join(' · '),
              style: AppText.caption),
        ],
      ),
    );
  }
}

/// Tarjeta de una operación de la bandeja del servidor.
class _OperacionTile extends StatelessWidget {
  const _OperacionTile({
    required this.operacion,
    required this.onConfirmar,
    required this.onDescartar,
  });

  final ServerOperation operacion;
  final VoidCallback? onConfirmar;
  final VoidCallback? onDescartar;

  @override
  Widget build(BuildContext context) {
    final rechazada = !operacion.enRevision;
    return AppCard(
      tone: rechazada ? AppCardTone.outlined : AppCardTone.normal,
      borderColor: rechazada ? AppColors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(operacion.titulo, style: AppText.bodySmStrong)),
              StatusBadge(operacion.estado,
                  tone: rechazada ? StatusTone.error : StatusTone.warning),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${operacion.entidad} · versión ${operacion.version} · '
            '${Fmt.date(operacion.capturadaEn)}, ${Fmt.time(operacion.capturadaEn)}',
            style: AppText.caption,
          ),
          if (operacion.motivo != null && operacion.motivo!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(operacion.motivo!, style: AppText.caption),
          ],
          if (operacion.enRevision) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                      label: 'Descartar',
                      color: AppColors.error,
                      onPressed: onDescartar),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      PrimaryButton(label: 'Confirmar', onPressed: onConfirmar),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
