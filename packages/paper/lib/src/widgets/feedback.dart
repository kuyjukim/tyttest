import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'buttons.dart';

/// What a screen shows before the user has made anything.
///
/// Empty states carry disproportionate weight in a paid app: for a first-run
/// user this screen *is* the product, so it states the single next action
/// rather than apologising for having no data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: Radii.allLg,
              ),
              child: Center(child: Icon(icon, size: 28, color: colors.accent)),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              title,
              style: context.type.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              message,
              style: context.type.body.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Gap.xxl),
              PaperButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens a modal sheet with the suite's chrome: a drag handle, rounded top
/// corners, and a height that never exceeds 92% of the screen.
Future<T?> showPaperSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    builder: (context) => _SheetFrame(title: title, child: builder(context)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Padding(
        // Lift the sheet above the keyboard when it holds a text field.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.md),
            Container(
              height: 4,
              width: 36,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: Radii.allPill,
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: Gap.lg),
              Text(title!, style: context.type.heading),
            ],
            const SizedBox(height: Gap.lg),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a short, non-blocking confirmation.
void showPaperToast(BuildContext context, String message, {IconData? icon}) {
  final colors = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: colors.surface),
              const SizedBox(width: Gap.sm),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Asks the user to confirm something irreversible.
///
/// Returns true only on an explicit confirm; a dismissed dialog is a "no".
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.colors.surfaceRaised,
      title: Text(title, style: context.type.heading),
      content: Text(message, style: context.type.body),
      actions: [
        PaperButton(
          label: 'Cancel',
          kind: PaperButtonKind.ghost,
          size: PaperButtonSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PaperButton(
          label: confirmLabel,
          kind: PaperButtonKind.danger,
          size: PaperButtonSize.small,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
