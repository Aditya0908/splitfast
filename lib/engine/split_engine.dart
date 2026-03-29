import '../models/bill_item.dart';
import '../models/bill_state.dart';

/// Result of the split calculation for a single participant.
class SplitResult {
  final String participantId;
  final double rawSubtotal;
  final double ratio;
  final double totalBeforeRounding;
  final double finalAmount;

  const SplitResult({
    required this.participantId,
    required this.rawSubtotal,
    required this.ratio,
    required this.totalBeforeRounding,
    required this.finalAmount,
  });

  @override
  String toString() =>
      'SplitResult($participantId: raw=$rawSubtotal, ratio=$ratio, final=$finalAmount)';
}

/// The proportional math engine. No penny drift allowed.
///
/// Implements the exact algorithm from the spec:
/// 1. Calculate raw shares per user from item assignments
/// 2. Apply proportional modifiers (discount, service charge, tax)
/// 3. Round each user's total to 2 decimal places
/// 4. Resolve any drift by adjusting the payer's share
class SplitEngine {
  const SplitEngine._();

  /// Calculate the split for all participants.
  ///
  /// [items] — the parsed bill items with participant assignments.
  /// [billState] — subtotal, tax, service charge, discount, finalTotal.
  /// [participantIds] — all participant IDs involved in this bill.
  /// [payerId] — the payer's participant ID (absorbs rounding drift).
  ///
  /// Returns a map of participantId -> SplitResult.
  /// Guarantees: sum of all finalAmounts == billState.finalTotal exactly.
  static Map<String, SplitResult> calculate({
    required List<BillItem> items,
    required BillState billState,
    required List<String> participantIds,
    required String payerId,
  }) {
    if (participantIds.isEmpty) return {};
    if (items.isEmpty) return _equalSplit(billState, participantIds, payerId);

    // Step 1: Calculate raw subtotals per user
    final rawSubtotals = <String, double>{};
    for (final id in participantIds) {
      rawSubtotals[id] = 0.0;
    }

    for (final item in items) {
      if (item.assignedParticipantIds.isEmpty) continue;
      final sharePerPerson =
          item.effectiveTotalPrice / item.assignedParticipantIds.length;
      for (final id in item.assignedParticipantIds) {
        rawSubtotals[id] = (rawSubtotals[id] ?? 0.0) + sharePerPerson;
      }
    }

    // Step 2: Calculate proportional modifiers
    final calculatedSubtotal =
        items.fold<double>(0.0, (sum, item) => sum + item.effectiveTotalPrice);

    // Guard against division by zero
    if (calculatedSubtotal == 0) {
      return _equalSplit(billState, participantIds, payerId);
    }

    final results = <String, SplitResult>{};

    for (final id in participantIds) {
      final userRawSubtotal = rawSubtotals[id] ?? 0.0;
      final userRatio = userRawSubtotal / calculatedSubtotal;

      final userTotalBeforeRounding = userRawSubtotal -
          (billState.discount * userRatio) +
          (billState.serviceCharge * userRatio) +
          (billState.totalTax * userRatio);

      // Step 3: Strict rounding to 2 decimal places
      final userFinalRounded =
          double.parse(userTotalBeforeRounding.toStringAsFixed(2));

      results[id] = SplitResult(
        participantId: id,
        rawSubtotal: userRawSubtotal,
        ratio: userRatio,
        totalBeforeRounding: userTotalBeforeRounding,
        finalAmount: userFinalRounded,
      );
    }

    // Step 4: Drift resolution — adjust the payer's share
    final sumOfAll =
        results.values.fold<double>(0.0, (sum, r) => sum + r.finalAmount);
    final drift =
        double.parse((billState.finalTotal - sumOfAll).toStringAsFixed(2));

    if (drift != 0.0 && results.containsKey(payerId)) {
      final payerResult = results[payerId]!;
      results[payerId] = SplitResult(
        participantId: payerResult.participantId,
        rawSubtotal: payerResult.rawSubtotal,
        ratio: payerResult.ratio,
        totalBeforeRounding: payerResult.totalBeforeRounding,
        finalAmount:
            double.parse((payerResult.finalAmount + drift).toStringAsFixed(2)),
      );
    }

    return results;
  }

  /// Equal split fallback (Quick Split Mode).
  static Map<String, SplitResult> equalSplit({
    required double finalTotal,
    required List<String> participantIds,
    required String payerId,
  }) {
    final billState = BillState(subtotal: finalTotal, finalTotal: finalTotal);
    return _equalSplit(billState, participantIds, payerId);
  }

  static Map<String, SplitResult> _equalSplit(
    BillState billState,
    List<String> participantIds,
    String payerId,
  ) {
    if (participantIds.isEmpty) return {};

    final perPerson = double.parse(
        (billState.finalTotal / participantIds.length).toStringAsFixed(2));
    final ratio = 1.0 / participantIds.length;

    final results = <String, SplitResult>{};
    for (final id in participantIds) {
      results[id] = SplitResult(
        participantId: id,
        rawSubtotal: perPerson,
        ratio: ratio,
        totalBeforeRounding: perPerson.toDouble(),
        finalAmount: perPerson,
      );
    }

    // Drift resolution
    final sumOfAll = perPerson * participantIds.length;
    final drift =
        double.parse((billState.finalTotal - sumOfAll).toStringAsFixed(2));

    if (drift != 0.0 && results.containsKey(payerId)) {
      final payerResult = results[payerId]!;
      results[payerId] = SplitResult(
        participantId: payerResult.participantId,
        rawSubtotal: payerResult.rawSubtotal,
        ratio: payerResult.ratio,
        totalBeforeRounding: payerResult.totalBeforeRounding,
        finalAmount:
            double.parse((payerResult.finalAmount + drift).toStringAsFixed(2)),
      );
    }

    return results;
  }

  /// Validate that the Gemini-parsed bill is internally consistent.
  /// Returns true if the math checks out within a small tolerance.
  static BillValidation validateParsedBill({
    required List<BillItem> items,
    required BillState billState,
    double tolerance = 1.0,
  }) {
    final calculatedSubtotal =
        items.fold<double>(0.0, (sum, item) => sum + item.effectiveTotalPrice);
    final calculatedFinal = calculatedSubtotal -
        billState.discount +
        billState.serviceCharge +
        billState.totalTax;

    final subtotalMatch =
        (calculatedSubtotal - billState.subtotal).abs() <= tolerance;
    final finalMatch =
        (calculatedFinal - billState.finalTotal).abs() <= tolerance;

    return BillValidation(
      isValid: subtotalMatch && finalMatch,
      calculatedSubtotal: calculatedSubtotal,
      reportedSubtotal: billState.subtotal,
      calculatedFinalTotal: calculatedFinal,
      reportedFinalTotal: billState.finalTotal,
      subtotalDiff: (calculatedSubtotal - billState.subtotal).abs(),
      finalDiff: (calculatedFinal - billState.finalTotal).abs(),
    );
  }
}

/// Result of bill validation against Gemini output.
class BillValidation {
  final bool isValid;
  final double calculatedSubtotal;
  final double reportedSubtotal;
  final double calculatedFinalTotal;
  final double reportedFinalTotal;
  final double subtotalDiff;
  final double finalDiff;

  const BillValidation({
    required this.isValid,
    required this.calculatedSubtotal,
    required this.reportedSubtotal,
    required this.calculatedFinalTotal,
    required this.reportedFinalTotal,
    required this.subtotalDiff,
    required this.finalDiff,
  });
}
