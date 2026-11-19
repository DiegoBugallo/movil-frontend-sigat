import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_text_field.dart';

/// Diálogo de confirmación estándar. Devuelve true si el usuario confirma.
/// `destructive: true` pinta la acción en rojo (cerrar sesión, descartar).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Aceptar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppText.h3),
      content: Text(message, style: AppText.body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.error : AppColors.primaryDark),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> showAppReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String label = 'Motivo',
  String hint = 'Explica brevemente la decisión',
  String confirmLabel = 'Enviar',
  bool destructive = false,
  int minimo = 5,
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  String? error;
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title, style: AppText.h3),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppText.body),
                const SizedBox(height: 12),
                AppTextField(
                  label: label,
                  controller: controller,
                  hint: hint,
                  maxLines: 3,
                  hasError: error != null,
                  helper: error,
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (texto.length < minimo) {
                      return 'Escribe al menos $minimo caracteres.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive ? AppColors.error : AppColors.primaryDark),
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  setState(
                      () => error = 'Escribe al menos $minimo caracteres.');
                  return;
                }
                Navigator.pop(ctx, controller.text.trim());
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// Protege un formulario a medio llenar.
///
/// Si `hasChanges` es true, el botón atrás de la barra (que usa `maybePop`)
/// y el atrás del sistema piden confirmación antes de salir. Si es false,
/// se sale sin preguntar. Envolver el `Scaffold` del formulario:
///
/// ```dart
/// DiscardChangesGuard(hasChanges: _dirty, child: Scaffold(...))
/// ```
class DiscardChangesGuard extends StatelessWidget {
  const DiscardChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
    this.message = 'Lo que escribiste en este formulario se perderá.',
  });

  final bool hasChanges;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await showAppConfirmDialog(
          context,
          title: '¿Salir sin guardar?',
          message: message,
          confirmLabel: 'Salir sin guardar',
          cancelLabel: 'Seguir editando',
          destructive: true,
        );
        if (salir && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
