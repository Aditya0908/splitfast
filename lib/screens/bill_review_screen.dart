import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';
import '../providers/providers.dart';
import '../services/recent_contacts_service.dart';
import '../widgets/bill_item_row.dart';
import '../widgets/bill_summary_bar.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/add_participant_dialog.dart';
import '../widgets/upi_input_dialog.dart';
import 'contact_picker_screen.dart';
import 'quick_split_screen.dart';
import 'split_result_screen.dart';

class BillReviewScreen extends ConsumerStatefulWidget {
  final String? imagePath;

  const BillReviewScreen({super.key, this.imagePath});

  @override
  ConsumerState<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends ConsumerState<BillReviewScreen> {
  final _uuid = const Uuid();

  // ── Item deletion with undo (spec: swipe left → SnackBar + Undo) ──
  void _deleteItem(String itemId, int index) {
    final deleted =
        ref.read(billItemsProvider.notifier).deleteItem(itemId);
    if (deleted == null) return;

    _recalcSubtotal();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${deleted.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(billItemsProvider.notifier).restoreItem(deleted, index);
            _recalcSubtotal();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Add item manually ────────────────────────────────────────
  Future<void> _addItem() async {
    final participants = ref.read(participantsProvider);
    final result = await showDialog<BillItem>(
      context: context,
      builder: (_) => AddItemDialog(
        participantIds: participants.map((p) => p.id).toList(),
      ),
    );
    if (result == null) return;

    ref.read(billItemsProvider.notifier).addItem(result);
    _recalcSubtotal();
  }

  // ── Add single participant by name ───────────────────────────
  Future<void> _addParticipantManually() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const AddParticipantDialog(),
    );
    if (name == null || name.isEmpty) return;

    final id = _uuid.v4();
    ref.read(participantsProvider.notifier).add(id, name);
    // Spec: new participant assigned to ALL items by default.
    ref.read(billItemsProvider.notifier).addParticipantToAllItems(id);
  }

  // ── Multi-select contact picker ──────────────────────────────
  Future<void> _pickContacts() async {
    final selected = await Navigator.of(context).push<List<SelectedContact>>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );
    if (selected == null || selected.isEmpty) return;

    // Save to recents for next time
    RecentContactsService.instance.addRecents(
      selected
          .map((c) => RecentContact(name: c.displayName, phone: c.phone))
          .toList(),
    );

    // Add each selected contact as a participant
    for (final contact in selected) {
      // Deduplicate: skip if a participant with this phone already exists
      final existing = ref.read(participantsProvider);
      final phone = Participant.normalizePhone(contact.phone);
      final alreadyAdded = existing.any((p) =>
          p.name == contact.displayName ||
          (phone.isNotEmpty && p.id == phone));

      if (alreadyAdded) continue;

      final id = phone.isNotEmpty ? phone : _uuid.v4();
      ref.read(participantsProvider.notifier).add(id, contact.displayName, phone: contact.phone);
      // Spec: new participant assigned to ALL items by default.
      ref.read(billItemsProvider.notifier).addParticipantToAllItems(id);
    }
  }

  // ── Recalculate subtotal from items ──────────────────────────
  void _recalcSubtotal() {
    final items = ref.read(billItemsProvider);
    final newSubtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.effectiveTotalPrice,
    );
    final bill = ref.read(billStateProvider);
    final newFinal =
        newSubtotal - bill.discount + bill.serviceCharge + bill.totalTax;
    ref.read(billStateProvider.notifier).updateSubtotal(newSubtotal);
    ref.read(billStateProvider.notifier).updateFinalTotal(
          double.parse(newFinal.toStringAsFixed(2)),
        );
  }

  void _goToResults() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SplitResultScreen()),
    );
  }

  /// Smart CTA: if UPI is missing, prompt for it first. Otherwise navigate.
  Future<void> _onCtaTapped() async {
    final payerUpiId = ref.read(payerUpiIdProvider);
    if (payerUpiId == null || payerUpiId.isEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => UpiInputDialog(currentUpiId: payerUpiId ?? ''),
      );
      if (result != null && result.isNotEmpty) {
        ref.read(payerUpiIdProvider.notifier).state = result;
        await RecentContactsService.instance.savePayerUpiId(result);
        // Re-check if we can now navigate
        if (!mounted) return;
        final canNow = ref.read(canGenerateLinksProvider);
        if (canNow) _goToResults();
      }
      return;
    }
    _goToResults();
  }

  /// CTA is enabled when items exist and all items have at least one assignee.
  /// The math + UPI checks are handled interactively on tap.
  bool _ctaEnabled(List<BillItem> items, bool canGenerate) {
    if (canGenerate) return true;
    // Enable if there are items and all are assigned (even if UPI missing — we'll prompt)
    return items.isNotEmpty &&
        items.every((item) => item.assignedParticipantIds.isNotEmpty);
  }

  /// Dynamic label: tells user what's missing.
  String _ctaLabel(WidgetRef ref) {
    final payerUpiId = ref.watch(payerUpiIdProvider);
    if (payerUpiId == null || payerUpiId.isEmpty) {
      return 'Set UPI & Share';
    }
    return 'View Split & Share';
  }

  void _fallbackToQuickSplit() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const QuickSplitScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(billItemsProvider);
    final participants = ref.watch(participantsProvider);
    final canGenerate = ref.watch(canGenerateLinksProvider);
    final scanState = ref.watch(scanProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Bill'),
        actions: [
          // Contact picker button
          IconButton(
            icon: const Icon(Icons.contacts_rounded),
            tooltip: 'Select friends',
            onPressed: _pickContacts,
          ),
          // Manual add fallback
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add person manually',
            onPressed: _addParticipantManually,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scan progress indicator (non-blocking) ───────────
          if (scanState.isProcessing)
            _ScanProgressBanner(stage: scanState.stage),

          // ── Scan failure banner with fallback ────────────────
          if (scanState.stage == ScanStage.failed)
            _ScanFailureBanner(
              message: scanState.errorMessage ?? 'Scan failed.',
              onQuickSplit: _fallbackToQuickSplit,
            ),

          // ── Participant chips bar ────────────────────────────
          if (participants.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: participants.map((p) {
                  final payerId = ref.watch(payerIdProvider);
                  final isPayer = p.id == payerId;
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: p.avatarColor,
                      child: Text(
                        p.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text(isPayer ? '${p.name} (You)' : p.name),
                    deleteIcon:
                        isPayer ? null : const Icon(Icons.close, size: 16),
                    onDeleted: isPayer
                        ? null
                        : () {
                            ref
                                .read(billItemsProvider.notifier)
                                .removeParticipantFromAllItems(p.id);
                            ref
                                .read(participantsProvider.notifier)
                                .remove(p.id);
                          },
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 1),

          // ── Item list ────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: scanState.isProcessing
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Scanning your bill...\nAdd people while you wait!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No items yet.\nTap + to add items manually.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return BillItemRow(
                        item: item,
                        participants: participants,
                        onToggleParticipant: (pid) {
                          ref
                              .read(billItemsProvider.notifier)
                              .toggleAssignment(item.id, pid);
                        },
                        onDismissed: () => _deleteItem(item.id, index),
                      );
                    },
                  ),
          ),

          // ── Bottom summary bar (always visible per spec) ────
          const BillSummaryBar(),

          // ── CTA ──────────────────────────────────────────────
          // Always enabled when items exist + all assigned.
          // If UPI is missing, tapping opens the UPI dialog first.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _ctaEnabled(items, canGenerate)
                      ? _onCtaTapped
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    _ctaLabel(ref),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _addItem,
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _ScanProgressBanner extends StatelessWidget {
  final ScanStage stage;
  const _ScanProgressBanner({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (stage) {
      ScanStage.ocr => 'Reading text from image...',
      ScanStage.gemini => 'Parsing bill with AI...',
      _ => 'Processing...',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _ScanFailureBanner extends StatelessWidget {
  final String message;
  final VoidCallback onQuickSplit;
  const _ScanFailureBanner({required this.message, required this.onQuickSplit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onQuickSplit,
            child: const Text('Quick Split'),
          ),
        ],
      ),
    );
  }
}
