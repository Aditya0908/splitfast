# SplitFast: Mobile App Architecture & Execution Specification

## 1. System Context & Directives for the AI Agent
You are an expert Flutter developer building "SplitFast", a zero-friction, item-level expense splitting mobile app.
**Core Objective:** Compress the "bill arrives" to "everyone pays" flow to under 45 seconds.
**App Model:** "Single Payer, Others Reimburse." Only the payer installs the app. Debtors receive UPI deep links via WhatsApp.
**Strict Constraints:** No backend ledger, no user auth. All logic is on-device or direct API to Gemini. Do NOT block the main UI thread during processing (use `compute` or isolates).

## 2. Technology Stack & Security
*   **Framework:** Flutter (Dart)
*   **State Management:** Riverpod (recommended for handling complex assignment matrix states).
*   **Local Storage:** `shared_preferences` (for saving Payer's UPI ID and recent contacts).
*   **Core Packages:** `google_mlkit_text_recognition`, `google_generative_ai`, `contacts_service`, `permission_handler`, `share_plus`, `url_launcher`.
*   **Security (CRITICAL):** Do NOT hardcode the Gemini API key. Implement `flutter_dotenv` to load the key from a `.env` file. Do not trust OCR text; sanitize before rendering.

## 3. Core Data Models (Strict Schema)
Implement these exact structures. Note the inclusion of `quantity` and UUIDs.

```dart
class Participant {
  final String id; // Use UUID or strictly normalized phone number (strip spaces/country codes)
  final String name;
  final String? upiId; // Payer's UPI ID is mandatory.
  final Color avatarColor;
}

class BillItem {
  final String id;
  String name;
  double price; // Unit price
  int quantity; // Default 1
  List<String> assignedParticipantIds; // Default: ALL participants at load
  
  double get effectiveTotalPrice => price * quantity;
}

class BillState {
  double subtotal;
  double totalTax;
  double serviceCharge;
  double discount;
  double finalTotal; // Ultimate source of truth
  String currency; // Default "INR"
}

## 4. Prompt Engineering & LLM Integration

Use google_generative_ai (Gemini Flash). Call this API asynchronously.
Prompt Rules:

Treat combo meals (e.g., "Burger + Fries 500") as atomic single items. Do NOT decompose them.

Ignore noise (if > 30 items, return failure).

Return STRICT JSON matching this schema:

code
JSON
download
content_copy
expand_less
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

## 5. Offline & Fallback Modes (Critical Flow)

Trigger: If network is offline, Gemini fails, or parsed subtotal == 0.
Action: Immediately transition to "Quick Split Mode".
UI:

Payer enters Final Amount manually.

Selects participants.

App falls back to Equal Split math.

## 6. Parsing Validation Layer (The Consistency Engine)

Do NOT blindly trust Gemini. Upon receiving JSON, run this check:

code
Dart
download
content_copy
expand_less
double calculatedSubtotal = items.fold(0, (sum, item) => sum + item.effectiveTotalPrice);
double calculatedFinal = calculatedSubtotal - discount + serviceCharge + tax;

bool isValid = (calculatedSubtotal ≈ subtotal) && (calculatedFinal ≈ final_total);

If !isValid: Show a prominent warning banner: "Math mismatch detected. Please review highlighted items." Mark the mismatched totals in red.

## 7. UI/UX State Machine & Micro-Interactions

Parallel Execution: While ML Kit / Gemini are parsing in the background, show the native Contacts multi-select UI. Do not make the user wait on a spinner.

Default State: Upon bill render, item.assignedParticipantIds must contain ALL selected participants. (Users remove themselves/others, which is faster than adding).

Visual Validation: If item.assignedParticipantIds.isEmpty, highlight the row in RED immediately.

Undo System: Implement a SnackBar with an "Undo" action when a user swipes left to delete an item row.

Scroll Complexity: Keep item rows dense. Use a bottom sheet or persistent header for the total math so it is always visible.

## 8. The Math & Rounding Engine (No Drift Allowed)

Implement this exact proportional math logic to ensure totals match to the penny.

code
Dart
download
content_copy
expand_less
// 1. Calculate raw shares
double userRawSubtotal = 0;
for (var item in items) {
  if (item.assignedParticipantIds.contains(userId)) {
    userRawSubtotal += (item.effectiveTotalPrice / item.assignedParticipantIds.length);
  }
}

// 2. Proportional Modifiers
double userRatio = userRawSubtotal / parsedBill.subtotal;
double userTotalBeforeRounding = userRawSubtotal 
    - (parsedBill.discount * userRatio) 
    + (parsedBill.serviceCharge * userRatio) 
    + (parsedBill.totalTax * userRatio);

// 3. Strict Rounding logic per user
double userFinalRounded = double.parse(userTotalBeforeRounding.toStringAsFixed(2));

// 4. Drift Resolution
double sumOfAllUsers = sum(all userFinalRounded);
double drift = double.parse((parsedBill.finalTotal - sumOfAllUsers).toStringAsFixed(2));

// Add the drift strictly to the Payer's share.
payerAmount += drift;
9. Payment Output Layer (UPI Deep Links)

The Payer must be prompted for their UPI ID before generating links (save this locally for future use).
Construct the WhatsApp share text exactly like this. Note the strict URI encoding.

code
Dart
download
content_copy
expand_less
String generateShareText(List<Participant> debtors, String payerUpiId, double finalTotal) {
  String message = "Dinner Split 🍕\nTotal: ₹${finalTotal.toStringAsFixed(2)}\n\n";
  
  for (var debtor in debtors) {
    if (debtor.id == payerId) continue;
    
    // STRICT UPI ENCODING RULES
    String encodedName = Uri.encodeComponent("SplitFast User");
    String formattedAmount = debtor.amountOwed.toStringAsFixed(2);
    String encodedNote = Uri.encodeComponent("SplitFast");
    
    String upiLink = "upi://pay?pa=$payerUpiId&pn=$encodedName&am=$formattedAmount&tn=$encodedNote&cu=INR";
    
    message += "@${debtor.name} -> ₹$formattedAmount\nPay here: $upiLink\n\n";
  }
  
  message += "(If links fail, my UPI ID is: $payerUpiId)";
  return message;
}
10. Final UI Checks before Export

The "Generate Links" CTA button MUST remain disabled until:

assignedParticipantIds.length > 0 for all items.

The user has entered their UPI ID.

The internal math engine validates that all user totals + payer total exactly equal finalTotal.
