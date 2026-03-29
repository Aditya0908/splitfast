import 'package:flutter/material.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';
import 'participant_avatar.dart';

/// A dense, swipeable item row with participant avatar chips.
/// Highlights RED when no participants are assigned (spec requirement).
class BillItemRow extends StatelessWidget {
  final BillItem item;
  final List<Participant> participants;
  final void Function(String participantId) onToggleParticipant;
  final VoidCallback onDismissed;

  const BillItemRow({
    super.key,
    required this.item,
    required this.participants,
    required this.onToggleParticipant,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = item.isUnassigned;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isError
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
              : null,
          border: isError
              ? Border.all(color: theme.colorScheme.error, width: 1)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Item info (name + price)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.quantity > 1
                        ? '${item.quantity} x ${_formatCurrency(item.price)} = ${_formatCurrency(item.effectiveTotalPrice)}'
                        : _formatCurrency(item.effectiveTotalPrice),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Avatar chips — tap to toggle
            Wrap(
              spacing: 4,
              children: participants.map((p) {
                final isAssigned =
                    item.assignedParticipantIds.contains(p.id);
                return ParticipantAvatar(
                  participant: p,
                  isAssigned: isAssigned,
                  onTap: () => onToggleParticipant(p.id),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) => '\u20B9${amount.toStringAsFixed(2)}';
}
