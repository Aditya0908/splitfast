import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'edit_value_dialog.dart';

/// Persistent bottom bar showing bill totals. Always visible per spec.
/// Tax, Service Charge, Discount, and Total are tappable for manual editing.
class BillSummaryBar extends ConsumerWidget {
  const BillSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billStateProvider);
    final validation = ref.watch(billValidationProvider);
    final theme = Theme.of(context);
    final isInvalid = validation != null && !validation.isValid;

    // Calculate what Total *should* be from components
    final expectedTotal =
        bill.subtotal - bill.discount + bill.serviceCharge + bill.totalTax;
    final totalMismatch =
        (expectedTotal - bill.finalTotal).abs() > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mismatch warning banner
            if (isInvalid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Math mismatch detected. Tap values below to correct.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Subtotal (read-only — derived from items)
            _SummaryRow(
              label: 'Subtotal',
              value: bill.subtotal,
              theme: theme,
            ),

            // Discount (editable)
            _EditableSummaryRow(
              label: 'Discount',
              value: bill.discount,
              displayValue: -bill.discount,
              theme: theme,
              color: bill.discount > 0 ? theme.colorScheme.tertiary : null,
              onEdit: (v) {
                ref.read(billStateProvider.notifier).updateDiscount(v);
                _recalcTotal(ref);
              },
            ),

            // Service Charge (editable)
            _EditableSummaryRow(
              label: 'Service Charge',
              value: bill.serviceCharge,
              theme: theme,
              onEdit: (v) {
                ref.read(billStateProvider.notifier).updateServiceCharge(v);
                _recalcTotal(ref);
              },
            ),

            // Tax (editable)
            _EditableSummaryRow(
              label: 'Tax',
              value: bill.totalTax,
              theme: theme,
              onEdit: (v) {
                ref.read(billStateProvider.notifier).updateTax(v);
                _recalcTotal(ref);
              },
            ),

            const Divider(height: 12),

            // Total (editable) + mismatch indicator
            _EditableSummaryRow(
              label: 'Total',
              value: bill.finalTotal,
              theme: theme,
              isBold: true,
              color: totalMismatch ? theme.colorScheme.error : null,
              showMismatch: totalMismatch,
              onEdit: (v) {
                ref.read(billStateProvider.notifier).updateFinalTotal(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _recalcTotal(WidgetRef ref) {
    final bill = ref.read(billStateProvider);
    final newTotal =
        bill.subtotal - bill.discount + bill.serviceCharge + bill.totalTax;
    ref.read(billStateProvider.notifier).updateFinalTotal(
          double.parse(newTotal.toStringAsFixed(2)),
        );
  }
}

// ─────────────────────────────────────────────────────────────────
// Read-only summary row (used for Subtotal)
// ─────────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final ThemeData theme;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\u20B9${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tappable summary row with pencil icon + optional mismatch badge
// ─────────────────────────────────────────────────────────────────
class _EditableSummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final double? displayValue; // if different from value (e.g. negative discount)
  final ThemeData theme;
  final bool isBold;
  final Color? color;
  final bool showMismatch;
  final ValueChanged<double> onEdit;

  const _EditableSummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.onEdit,
    this.displayValue,
    this.isBold = false,
    this.color,
    this.showMismatch = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: color)
        : theme.textTheme.bodyMedium?.copyWith(color: color);

    final display = displayValue ?? value;

    return InkWell(
      onTap: () async {
        final result = await showDialog<double>(
          context: context,
          builder: (_) => EditValueDialog(label: label, currentValue: value),
        );
        if (result != null) onEdit(result);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            // Label with pencil icon
            Icon(Icons.edit_rounded,
                size: 12,
                color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: style?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                  decorationColor: color ?? theme.colorScheme.onSurfaceVariant,
                )),

            const Spacer(),

            // Mismatch indicator
            if (showMismatch) ...[
              Icon(Icons.error_rounded,
                  size: 14, color: theme.colorScheme.error),
              const SizedBox(width: 4),
            ],

            // Value
            Text(
              '\u20B9${display.abs().toStringAsFixed(2)}${display < 0 ? ' off' : ''}',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
