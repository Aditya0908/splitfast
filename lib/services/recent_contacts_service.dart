import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists recently-used contact names + phone numbers for quick re-selection.
class RecentContactsService {
  RecentContactsService._();
  static final instance = RecentContactsService._();

  static const _key = 'recent_contacts';
  static const _maxRecents = 20;

  /// A recent contact entry: name + phone.
  /// Stored as JSON in shared_preferences.
  Future<List<RecentContact>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return [];

    return raw.map((json) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return RecentContact(
        name: map['name'] as String,
        phone: map['phone'] as String? ?? '',
      );
    }).toList();
  }

  /// Add contacts to the recents list (deduplicates by phone).
  Future<void> addRecents(List<RecentContact> contacts) async {
    final existing = await getRecents();
    final existingPhones = existing.map((c) => c.phone).toSet();

    for (final c in contacts) {
      if (c.phone.isNotEmpty && !existingPhones.contains(c.phone)) {
        existing.insert(0, c);
        existingPhones.add(c.phone);
      } else if (c.phone.isEmpty && !existing.any((e) => e.name == c.name)) {
        existing.insert(0, c);
      }
    }

    // Trim to max
    final trimmed = existing.take(_maxRecents).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      trimmed.map((c) => jsonEncode({'name': c.name, 'phone': c.phone})).toList(),
    );
  }

  /// Save the payer's UPI ID for reuse across sessions.
  Future<void> savePayerUpiId(String upiId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payer_upi_id', upiId);
  }

  /// Load the payer's saved UPI ID.
  Future<String?> loadPayerUpiId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('payer_upi_id');
  }
}

class RecentContact {
  final String name;
  final String phone;

  const RecentContact({required this.name, this.phone = ''});
}
