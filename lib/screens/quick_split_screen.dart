import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_state.dart';
import '../models/participant.dart';
import '../providers/providers.dart';
import '../services/recent_contacts_service.dart';
import '../widgets/add_participant_dialog.dart';
import 'contact_picker_screen.dart';
import 'split_result_screen.dart';

/// Fallback mode: Payer enters final amount, picks participants, equal split.
class QuickSplitScreen extends ConsumerStatefulWidget {
  const QuickSplitScreen({super.key});

  @override
  ConsumerState<QuickSplitScreen> createState() => _QuickSplitScreenState();
}

class _QuickSplitScreenState extends ConsumerState<QuickSplitScreen> {
  final _amountCtrl = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _addParticipantManually() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const AddParticipantDialog(),
    );
    if (name == null || name.isEmpty) return;
    ref.read(participantsProvider.notifier).add(_uuid.v4(), name);
  }

  Future<void> _pickContacts() async {
    final selected = await Navigator.of(context).push<List<SelectedContact>>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );
    if (selected == null || selected.isEmpty) return;

    RecentContactsService.instance.addRecents(
      selected
          .map((c) => RecentContact(name: c.displayName, phone: c.phone))
          .toList(),
    );

    for (final contact in selected) {
      final existing = ref.read(participantsProvider);
      final phone = Participant.normalizePhone(contact.phone);
      final alreadyAdded = existing.any((p) =>
          p.name == contact.displayName ||
          (phone.isNotEmpty && p.id == phone));
      if (alreadyAdded) continue;

      final id = phone.isNotEmpty ? phone : _uuid.v4();
      ref.read(participantsProvider.notifier).add(id, contact.displayName, phone: contact.phone);
    }
  }

  void _calculate() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final participants = ref.read(participantsProvider);
    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one other person')),
      );
      return;
    }

    final payerId = ref.read(payerIdProvider);
    if (payerId == null) return;

    ref.read(billStateProvider.notifier).load(
          BillState(subtotal: amount, finalTotal: amount),
        );
    ref.read(billItemsProvider.notifier).clear();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SplitResultScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(participantsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Split')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the total bill amount and split equally.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Amount input
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium,
              decoration: InputDecoration(
                labelText: 'Total Amount',
                prefixText: '\u20B9 ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),

            const SizedBox(height: 24),

            // Participants header with both add options
            Row(
              children: [
                Text(
                  'People (${participants.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickContacts,
                  icon: const Icon(Icons.contacts_rounded, size: 18),
                  label: const Text('Contacts'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _addParticipantManually,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: participants.isEmpty
                  ? Center(
                      child: Text(
                        'Add people to split with',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final p = participants[index];
                        final isPayer = p.id == ref.watch(payerIdProvider);
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: p.avatarColor,
                            child: Text(
                              p.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(isPayer ? '${p.name} (You)' : p.name),
                          trailing: isPayer
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => ref
                                      .read(participantsProvider.notifier)
                                      .remove(p.id),
                                ),
                        );
                      },
                    ),
            ),

            // Split button
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text(
                  'Split Equally',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
