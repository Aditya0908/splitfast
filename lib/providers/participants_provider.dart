import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/participant.dart';

/// A fixed palette of avatar colours cycled through as participants are added.
const _avatarColors = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFFFF5722),
  Color(0xFF607D8B),
  Color(0xFF8BC34A),
  Color(0xFFFFC107),
];

class ParticipantsNotifier extends StateNotifier<List<Participant>> {
  ParticipantsNotifier() : super([]);

  Color _nextColor() => _avatarColors[state.length % _avatarColors.length];

  /// Add a participant and return the generated object.
  Participant add(String id, String name, {String? upiId, String? phone}) {
    final p = Participant(
      id: id,
      name: name,
      upiId: upiId,
      phone: phone,
      avatarColor: _nextColor(),
    );
    state = [...state, p];
    return p;
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateUpiId(String id, String upiId) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(upiId: upiId) else p,
    ];
  }

  void loadAll(List<Participant> participants) {
    state = participants;
  }

  void clear() => state = [];
}

final participantsProvider =
    StateNotifierProvider<ParticipantsNotifier, List<Participant>>(
  (ref) => ParticipantsNotifier(),
);

/// The payer's participant ID.
final payerIdProvider = StateProvider<String?>((ref) => null);

/// The payer's saved UPI ID (persisted via shared_preferences externally).
final payerUpiIdProvider = StateProvider<String?>((ref) => null);
