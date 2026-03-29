import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../providers/share_queue_provider.dart';
import '../services/payment_service.dart';
import '../services/recent_contacts_service.dart';
import '../widgets/upi_input_dialog.dart';

/// Shows per-person split results, UPI ID entry, group share, and
/// sequential WhatsApp share queue with resume detection.
class SplitResultScreen extends ConsumerStatefulWidget {
  const SplitResultScreen({super.key});

  @override
  ConsumerState<SplitResultScreen> createState() => _SplitResultScreenState();
}

class _SplitResultScreenState extends ConsumerState<SplitResultScreen>
    with WidgetsBindingObserver {
  bool _waitingForResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForResume) {
      _waitingForResume = false;
      _onResumedFromWhatsApp();
    }
  }

  // ── Start the sequential share queue ───────────────────────────
  void _startSequence() {
    final participants = ref.read(participantsProvider);
    final splitResults = ref.read(splitResultsProvider);
    final payerId = ref.read(payerIdProvider)!;
    final payerUpiId = ref.read(payerUpiIdProvider)!;

    // Build queue entries for debtors only (skip payer)
    final entries = <ShareQueueEntry>[];
    for (final p in participants) {
      if (p.id == payerId) continue;
      final result = splitResults[p.id];
      if (result == null) continue;

      entries.add(ShareQueueEntry(
        participantId: p.id,
        name: p.name,
        whatsappPhone: p.whatsappPhone,
        amount: result.finalAmount,
        upiLink: PaymentService.instance.generateUpiLink(
          payerUpiId: payerUpiId,
          amount: result.finalAmount,
        ),
      ));
    }

    if (entries.isEmpty) return;

    ref.read(shareQueueProvider.notifier).initialize(entries);
    _sendCurrentEntry();
  }

  // ── Send WhatsApp intent for the current queue entry ───────────
  Future<void> _sendCurrentEntry() async {
    final queue = ref.read(shareQueueProvider);
    final entry = queue.currentEntry;
    if (entry == null) return;

    final payerUpiId = ref.read(payerUpiIdProvider)!;
    final message = PaymentService.instance.generateIndividualMessage(
      name: entry.name,
      amount: entry.amount,
      payerUpiId: payerUpiId,
    );

    if (entry.whatsappPhone != null && entry.whatsappPhone!.isNotEmpty) {
      // Direct WhatsApp intent with phone number
      final encodedText = Uri.encodeComponent(message);
      final uri = Uri.parse(
        'whatsapp://send?phone=${entry.whatsappPhone}&text=$encodedText',
      );

      if (await canLaunchUrl(uri)) {
        _waitingForResume = true;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Fallback: open WhatsApp without phone (user picks contact)
    final encodedText = Uri.encodeComponent(message);
    final fallbackUri = Uri.parse('whatsapp://send?text=$encodedText');

    if (await canLaunchUrl(fallbackUri)) {
      _waitingForResume = true;
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not found on this device.')),
      );
    }
  }

  // ── Called when user returns from WhatsApp ─────────────────────
  void _onResumedFromWhatsApp() {
    final queue = ref.read(shareQueueProvider);
    if (!queue.isActive) return;

    // Mark current as sent and advance
    ref.read(shareQueueProvider.notifier).markCurrentSentAndAdvance();

    final updated = ref.read(shareQueueProvider);

    if (updated.isComplete) {
      // Show celebration
      _showCompletionDialog();
    } else {
      // Show "Send Next" bottom sheet
      _showResumeSheet(updated);
    }
  }

  // ── Bottom sheet: "Sent to X. Next: Y" + SEND NEXT button ─────
  void _showResumeSheet(ShareQueueState queue) {
    final lastSent = queue.lastSentEntry;
    final next = queue.currentEntry;
    if (next == null) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sent confirmation
                if (lastSent != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Sent to ${lastSent.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Progress indicator
                Text(
                  '${queue.sentCount} of ${queue.entries.length} sent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: queue.sentCount / queue.entries.length,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 20),

                // Next person info
                Text(
                  'Next: ${next.name}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\u20B9${next.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Giant SEND NEXT button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _sendCurrentEntry();
                    },
                    icon: const Icon(Icons.send_rounded, size: 24),
                    label: Text(
                      'SEND NEXT',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Skip / stop option
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(shareQueueProvider.notifier).reset();
                  },
                  child: const Text('Stop Sequence'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Celebration dialog when all shares are sent ────────────────
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'All Shares Sent!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everyone has been notified with their payment links.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(shareQueueProvider.notifier).reset();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ── UPI ID prompt + persist ────────────────────────────────────
  Future<void> _promptUpiId() async {
    final current = ref.read(payerUpiIdProvider) ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (_) => UpiInputDialog(currentUpiId: current),
    );
    if (result != null && result.isNotEmpty) {
      ref.read(payerUpiIdProvider.notifier).state = result;
      await RecentContactsService.instance.savePayerUpiId(result);
    }
  }

  // ── Group share via share sheet ────────────────────────────────
  void _onGroupShare() {
    final participants = ref.read(participantsProvider);
    final splitResults = ref.read(splitResultsProvider);
    final payerId = ref.read(payerIdProvider)!;
    final payerUpiId = ref.read(payerUpiIdProvider)!;
    final billState = ref.read(billStateProvider);

    final shareText = PaymentService.instance.generateShareText(
      participants: participants,
      splitResults: splitResults,
      payerId: payerId,
      payerUpiId: payerUpiId,
      finalTotal: billState.finalTotal,
    );

    Share.share(shareText, subject: 'SplitFast Payment Links');
  }

  // ── Launch a single UPI deep link ──────────────────────────────
  Future<void> _launchUpiLink(String payerUpiId, double amount) async {
    final link = PaymentService.instance.generateUpiLink(
      payerUpiId: payerUpiId,
      amount: amount,
    );

    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(participantsProvider);
    final splitResults = ref.watch(splitResultsProvider);
    final payerId = ref.watch(payerIdProvider);
    final payerUpiId = ref.watch(payerUpiIdProvider);
    final billState = ref.watch(billStateProvider);
    final canGenerate = ref.watch(canGenerateLinksProvider);
    final queue = ref.watch(shareQueueProvider);
    final theme = Theme.of(context);

    // Check if any debtor has a phone number (for sequence button)
    final hasAnyPhone = participants.any(
      (p) => p.id != payerId && p.whatsappPhone != null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Split Results')),
      body: Column(
        children: [
          // ── Active queue progress banner ──────────────────────
          if (queue.isActive && !queue.isComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.send_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Sharing: ${queue.sentCount}/${queue.entries.length} sent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(shareQueueProvider.notifier).reset(),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),

          // ── Per-person breakdown ──────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final p = participants[index];
                final result = splitResults[p.id];
                final amount = result?.finalAmount ?? 0.0;
                final isPayer = p.id == payerId;

                // Check if this person has been sent in the queue
                final queueEntry = queue.isActive
                    ? queue.entries
                        .where((e) => e.participantId == p.id)
                        .firstOrNull
                    : null;
                final isSent = queueEntry?.sent ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.avatarColor,
                      child: isSent
                          ? Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : Text(
                              p.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(
                      isPayer ? '${p.name} (You)' : p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: isSent ? TextDecoration.lineThrough : null,
                        color: isSent
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    subtitle: isPayer
                        ? const Text('Your share (drift-adjusted)')
                        : isSent
                            ? Text('Sent',
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500))
                            : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\u20B9${amount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPayer
                                ? theme.colorScheme.primary
                                : isSent
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                          ),
                        ),
                        // Individual UPI pay button for each debtor
                        if (!isPayer &&
                            payerUpiId != null &&
                            payerUpiId.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: Icon(Icons.payment_rounded,
                                  color: theme.colorScheme.primary, size: 20),
                              tooltip: 'Open UPI payment',
                              onPressed: () =>
                                  _launchUpiLink(payerUpiId, amount),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Total footer ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bill Total',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '\u20B9${billState.finalTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── UPI ID status + entry ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payerUpiId != null && payerUpiId.isNotEmpty
                        ? 'UPI: $payerUpiId'
                        : 'No UPI ID set',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: payerUpiId != null && payerUpiId.isNotEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _promptUpiId,
                  child: Text(
                    payerUpiId != null && payerUpiId.isNotEmpty
                        ? 'Change'
                        : 'Set UPI ID',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Share buttons ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: canGenerate ? _onGroupShare : null,
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'Share Group Summary',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),

          // ── Sequential WhatsApp share button ─────────────────
          if (hasAnyPhone)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: canGenerate && !queue.isActive
                        ? _startSequence
                        : null,
                    icon: const Icon(Icons.message_rounded),
                    label: Text(
                      queue.isActive
                          ? 'Sequence in progress...'
                          : 'Share Individually (Sequence)',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),

          // SafeArea bottom padding when no sequence button
          if (!hasAnyPhone) const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }
}
