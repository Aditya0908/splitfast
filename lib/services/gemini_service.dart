import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_item.dart';
import '../models/bill_state.dart';

/// The result of a successful Gemini parse.
class GeminiParseResult {
  final List<BillItem> items;
  final BillState billState;

  const GeminiParseResult({required this.items, required this.billState});
}

/// Failure reasons for Gemini parsing.
enum GeminiFailureReason { noApiKey, networkError, invalidJson, tooManyItems, zeroSubtotal }

class GeminiFailure {
  final GeminiFailureReason reason;
  final String message;

  const GeminiFailure({required this.reason, required this.message});

  @override
  String toString() => 'GeminiFailure($reason: $message)';
}

/// Gemini Flash integration for structuring OCR text into bill data.
/// API key loaded from .env via flutter_dotenv — NEVER hardcoded.
class GeminiService {
  GeminiService._();
  static final instance = GeminiService._();

  static const _uuid = Uuid();

  /// The strict prompt sent to Gemini Flash.
  /// Enforces combo-meal atomicity, strict JSON schema, and the >30 items guard.
  static const _systemPrompt = '''
You are a receipt/bill parser. Given raw OCR text from a restaurant bill, extract the structured data.

RULES:
1. Treat combo meals (e.g., "Burger + Fries 500", "Meal Deal 799") as a SINGLE atomic item. Do NOT decompose them into sub-items.
2. If you detect more than 30 line items, return ONLY: {"error": "TOO_MANY_ITEMS"}
3. Ignore noise, headers, footers, addresses, phone numbers — only extract food/drink items and totals.
4. "quantity" defaults to 1 if not explicitly stated on the receipt.
5. "price" is the UNIT price for one quantity of that item.
6. For currency, default to "INR" unless the receipt clearly shows otherwise.
7. If you cannot determine a value, use 0.

Return STRICT JSON matching this EXACT schema — no markdown fences, no commentary, ONLY the JSON object:

{
  "items": [
    {"name": "String", "price": Number, "quantity": Number}
  ],
  "subtotal": Number,
  "discount": Number,
  "service_charge": Number,
  "tax": Number,
  "final_total": Number,
  "currency": "INR"
}
''';

  /// Parse OCR text into structured bill data via Gemini Flash.
  ///
  /// Returns a [GeminiParseResult] on success, or throws a [GeminiFailure].
  Future<GeminiParseResult> parseOcrText(String ocrText) async {
    // Load API key from .env
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw const GeminiFailure(
        reason: GeminiFailureReason.noApiKey,
        message: 'GEMINI_API_KEY not set in .env file.',
      );
    }

    // Configure model
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(_systemPrompt),
    );

    // Call Gemini
    final GenerateContentResponse response;
    try {
      response = await model.generateContent([
        Content.text('Parse this receipt:\n\n$ocrText'),
      ]);
    } catch (e) {
      throw GeminiFailure(
        reason: GeminiFailureReason.networkError,
        message: 'Gemini API call failed: $e',
      );
    }

    final rawJson = response.text?.trim();
    if (rawJson == null || rawJson.isEmpty) {
      throw const GeminiFailure(
        reason: GeminiFailureReason.invalidJson,
        message: 'Gemini returned empty response.',
      );
    }

    return _parseJson(rawJson);
  }

  /// Parse and validate the JSON response from Gemini.
  GeminiParseResult _parseJson(String rawJson) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (e) {
      throw GeminiFailure(
        reason: GeminiFailureReason.invalidJson,
        message: 'Failed to decode Gemini JSON: $e',
      );
    }

    // Check for the >30 items error signal
    if (json.containsKey('error') && json['error'] == 'TOO_MANY_ITEMS') {
      throw const GeminiFailure(
        reason: GeminiFailureReason.tooManyItems,
        message: 'Receipt has more than 30 items.',
      );
    }

    // Parse items
    final itemsList = json['items'] as List<dynamic>? ?? [];

    // Guard: >30 items
    if (itemsList.length > 30) {
      throw const GeminiFailure(
        reason: GeminiFailureReason.tooManyItems,
        message: 'Receipt has more than 30 items.',
      );
    }

    final items = itemsList.map((raw) {
      final map = raw as Map<String, dynamic>;
      return BillItem(
        id: _uuid.v4(),
        name: _sanitize(map['name']?.toString() ?? 'Unknown Item'),
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    // Parse totals
    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (json['discount'] as num?)?.toDouble() ?? 0.0;
    final serviceCharge = (json['service_charge'] as num?)?.toDouble() ?? 0.0;
    final tax = (json['tax'] as num?)?.toDouble() ?? 0.0;
    final finalTotal = (json['final_total'] as num?)?.toDouble() ?? 0.0;
    final currency = json['currency']?.toString() ?? 'INR';

    // Guard: zero subtotal → fallback
    if (subtotal == 0.0 && finalTotal == 0.0) {
      throw const GeminiFailure(
        reason: GeminiFailureReason.zeroSubtotal,
        message: 'Parsed subtotal is zero — likely a bad parse.',
      );
    }

    final billState = BillState(
      subtotal: subtotal,
      totalTax: tax,
      serviceCharge: serviceCharge,
      discount: discount,
      finalTotal: finalTotal,
      currency: currency,
    );

    return GeminiParseResult(items: items, billState: billState);
  }

  /// Sanitize OCR text before rendering in the UI.
  /// Strips control characters and excessive whitespace.
  static String _sanitize(String raw) {
    return raw
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // strip control chars
        .replaceAll(RegExp(r'\s+'), ' ')             // collapse whitespace
        .trim();
  }
}
