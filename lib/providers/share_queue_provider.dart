import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single entry in the sequential share queue.
class ShareQueueEntry {
  final String participantId;
  final String name;
  final String? whatsappPhone; // Already formatted with country code
  final double amount;
  final String upiLink;
  final bool sent;

  const ShareQueueEntry({
    required this.participantId,
    required this.name,
    required this.whatsappPhone,
    required this.amount,
    required this.upiLink,
    this.sent = false,
  });

  ShareQueueEntry copyWith({bool? sent}) => ShareQueueEntry(
        participantId: participantId,
        name: name,
        whatsappPhone: whatsappPhone,
        amount: amount,
        upiLink: upiLink,
        sent: sent ?? this.sent,
      );
}

/// Immutable state for the share queue.
class ShareQueueState {
  final List<ShareQueueEntry> entries;
  final int currentIndex;
  final bool isActive;

  const ShareQueueState({
    this.entries = const [],
    this.currentIndex = 0,
    this.isActive = false,
  });

  bool get isComplete =>
      isActive && entries.isNotEmpty && currentIndex >= entries.length;

  ShareQueueEntry? get currentEntry =>
      currentIndex < entries.length ? entries[currentIndex] : null;

  ShareQueueEntry? get lastSentEntry {
    if (currentIndex == 0) return null;
    return entries[currentIndex - 1];
  }

  int get sentCount => entries.where((e) => e.sent).length;

  ShareQueueState copyWith({
    List<ShareQueueEntry>? entries,
    int? currentIndex,
    bool? isActive,
  }) =>
      ShareQueueState(
        entries: entries ?? this.entries,
        currentIndex: currentIndex ?? this.currentIndex,
        isActive: isActive ?? this.isActive,
      );
}

class ShareQueueNotifier extends StateNotifier<ShareQueueState> {
  ShareQueueNotifier() : super(const ShareQueueState());

  /// Load the queue with debtor entries (excludes the payer).
  void initialize(List<ShareQueueEntry> entries) {
    state = ShareQueueState(
      entries: entries,
      currentIndex: 0,
      isActive: true,
    );
  }

  /// Mark the current entry as sent and advance to the next.
  void markCurrentSentAndAdvance() {
    if (state.currentIndex >= state.entries.length) return;

    final updated = List<ShareQueueEntry>.from(state.entries);
    updated[state.currentIndex] = updated[state.currentIndex].copyWith(sent: true);

    state = state.copyWith(
      entries: updated,
      currentIndex: state.currentIndex + 1,
    );
  }

  /// Reset the queue.
  void reset() {
    state = const ShareQueueState();
  }
}

final shareQueueProvider =
    StateNotifierProvider<ShareQueueNotifier, ShareQueueState>(
  (ref) => ShareQueueNotifier(),
);
