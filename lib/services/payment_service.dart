import '../engine/split_engine.dart';
import '../models/participant.dart';

/// Generates UPI deep links and WhatsApp share text per the spec (Section 9).
class PaymentService {
  PaymentService._();
  static final instance = PaymentService._();

  /// Sanitize a UPI VPA: trim whitespace, remove any internal spaces.
  String _sanitizeVpa(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), '');

  /// Sanitize a payee name for GPay compatibility:
  /// - Only alphabets and spaces
  /// - Truncated to 20 characters
  /// - Defaults to 'Payer' if empty after sanitization
  String _sanitizeName(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    if (cleaned.isEmpty) cleaned = 'Payer';
    if (cleaned.length > 20) cleaned = cleaned.substring(0, 20).trimRight();
    return cleaned;
  }

  /// Generate the full WhatsApp-ready share text with UPI deep links.
  /// UPI links are placed on their own line with clear newlines around them
  /// so WhatsApp doesn't swallow trailing characters into the URL.
  String generateShareText({
    required List<Participant> participants,
    required Map<String, SplitResult> splitResults,
    required String payerId,
    required String payerUpiId,
    required double finalTotal,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Dinner Split \u{1F355}');
    buffer.writeln('Total: \u20B9${finalTotal.toStringAsFixed(2)}');
    buffer.writeln();

    for (final p in participants) {
      if (p.id == payerId) continue;

      final result = splitResults[p.id];
      if (result == null) continue;

      final formattedAmount = result.finalAmount.toStringAsFixed(2);
      final upiLink = generateUpiLink(
        payerUpiId: payerUpiId,
        amount: result.finalAmount,
      );

      buffer.writeln('@${p.name} -> \u20B9$formattedAmount');
      buffer.writeln('Pay here:');
      buffer.writeln(upiLink);
      buffer.writeln();
    }

    buffer.write('(If links fail, my UPI ID is: ${_sanitizeVpa(payerUpiId)})');
    return buffer.toString();
  }

  /// Generate a personalized WhatsApp message for one person.
  /// UPI link is on its own line with clear newlines so WhatsApp
  /// doesn't accidentally include trailing characters in the URL.
  String generateIndividualMessage({
    required String name,
    required double amount,
    required String payerUpiId,
  }) {
    final formattedAmount = amount.toStringAsFixed(2);
    final upiLink = generateUpiLink(
      payerUpiId: payerUpiId,
      amount: amount,
    );

    final buffer = StringBuffer();
    buffer.writeln('Hey $name, here is your split: \u20B9$formattedAmount');
    buffer.writeln();
    buffer.writeln('Pay here:');
    buffer.writeln(upiLink);
    buffer.writeln();
    buffer.write('(If link fails, my UPI ID is: ${_sanitizeVpa(payerUpiId)})');
    return buffer.toString();
  }

  /// Generate a single UPI deep link with strict GPay-compatible encoding.
  ///
  /// Rules:
  /// 1. VPA (pa) — trimmed, no whitespace
  /// 2. Payee Name (pn) — alphabets + spaces only, max 20 chars
  /// 3. Amount (am) — always 2 decimal places
  /// 4. Built with Uri class for correct %20 encoding
  String generateUpiLink({
    required String payerUpiId,
    required double amount,
    String payeeName = '',
  }) {
    final sanitizedVpa = _sanitizeVpa(payerUpiId);
    final sanitizedName = _sanitizeName(payeeName);
    final formattedAmount = amount.toStringAsFixed(2);

    final upiUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': sanitizedVpa,
        'pn': sanitizedName,
        'am': formattedAmount,
        'cu': 'INR',
        'tn': 'SplitFast',
      },
    );

    return upiUri.toString();
  }
}
