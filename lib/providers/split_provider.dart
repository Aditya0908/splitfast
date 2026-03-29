import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/split_engine.dart';
import 'bill_provider.dart';
import 'participants_provider.dart';

/// Live-computed split results. Recalculates whenever items, bill state,
/// participants, or payer changes.
final splitResultsProvider = Provider<Map<String, SplitResult>>((ref) {
  final items = ref.watch(billItemsProvider);
  final billState = ref.watch(billStateProvider);
  final participants = ref.watch(participantsProvider);
  final payerId = ref.watch(payerIdProvider);

  if (participants.isEmpty || payerId == null) return {};

  return SplitEngine.calculate(
    items: items,
    billState: billState,
    participantIds: participants.map((p) => p.id).toList(),
    payerId: payerId,
  );
});

/// Live-computed bill validation against parsed totals.
final billValidationProvider = Provider<BillValidation?>((ref) {
  final items = ref.watch(billItemsProvider);
  final billState = ref.watch(billStateProvider);

  if (items.isEmpty) return null;

  return SplitEngine.validateParsedBill(
    items: items,
    billState: billState,
  );
});

/// Gate for the "Generate Links" CTA button.
/// True only when ALL spec conditions are met.
final canGenerateLinksProvider = Provider<bool>((ref) {
  final items = ref.watch(billItemsProvider);
  final participants = ref.watch(participantsProvider);
  final payerUpiId = ref.watch(payerUpiIdProvider);
  final splitResults = ref.watch(splitResultsProvider);
  final billState = ref.watch(billStateProvider);

  // Condition 1: Every item has at least one participant assigned.
  final allAssigned = items.isNotEmpty &&
      items.every((item) => item.assignedParticipantIds.isNotEmpty);

  // Condition 2: Payer has entered a UPI ID.
  final hasUpi = payerUpiId != null && payerUpiId.isNotEmpty;

  // Condition 3: Math validates — sum of all splits == finalTotal.
  bool mathValid = false;
  if (splitResults.isNotEmpty && participants.isNotEmpty) {
    final sum = splitResults.values
        .fold<double>(0.0, (s, r) => s + r.finalAmount);
    mathValid =
        (double.parse(sum.toStringAsFixed(2)) == billState.finalTotal);
  }

  return allAssigned && hasUpi && mathValid;
});
