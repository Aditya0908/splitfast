import 'package:flutter/material.dart';

class Participant {
  final String id;
  final String name;
  final String? upiId;
  final String? phone; // Raw phone number from contacts
  final Color avatarColor;

  const Participant({
    required this.id,
    required this.name,
    this.upiId,
    this.phone,
    required this.avatarColor,
  });

  Participant copyWith({
    String? id,
    String? name,
    String? upiId,
    String? phone,
    Color? avatarColor,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      phone: phone ?? this.phone,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  /// Normalize a phone number by stripping spaces, dashes, and country code prefix.
  static String normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Strip leading country code for India (91) if 12+ digits
    if (digits.length >= 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  /// Get phone number with country code for WhatsApp intent.
  /// If no country code present, defaults to +91 (India).
  String? get whatsappPhone {
    if (phone == null || phone!.isEmpty) return null;
    String digits = phone!.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // If 10 digits (Indian local), prepend 91
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
