import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_item.dart';
import '../models/bill_state.dart';

/// Manages the list of bill items (CRUD + assignment toggling).
class BillItemsNotifier extends StateNotifier<List<BillItem>> {
  BillItemsNotifier() : super([]);

  /// Load items from Gemini parse result. Auto-assigns ALL participant IDs.
  void loadItems(List<BillItem> items, List<String> participantIds) {
    state = items.map((item) {
      return item.copyWith(
        assignedParticipantIds: List.from(participantIds),
      );
    }).toList();
  }

  /// Toggle a participant's assignment on a specific item.
  void toggleAssignment(String itemId, String participantId) {
    state = [
      for (final item in state)
        if (item.id == itemId)
          item.copyWith(
            assignedParticipantIds:
                item.assignedParticipantIds.contains(participantId)
                    ? (List.from(item.assignedParticipantIds)
                      ..remove(participantId))
                    : (List.from(item.assignedParticipantIds)
                      ..add(participantId)),
          )
        else
          item,
    ];
  }

  /// Assign a participant to all items at once.
  void assignToAll(String participantId) {
    state = [
      for (final item in state)
        if (!item.assignedParticipantIds.contains(participantId))
          item.copyWith(
            assignedParticipantIds: List.from(item.assignedParticipantIds)
              ..add(participantId),
          )
        else
          item,
    ];
  }

  /// Remove a participant from all items at once.
  void removeFromAll(String participantId) {
    state = [
      for (final item in state)
        item.copyWith(
          assignedParticipantIds: List.from(item.assignedParticipantIds)
            ..remove(participantId),
        ),
    ];
  }

  /// Delete an item by ID. Returns the deleted item for undo.
  BillItem? deleteItem(String itemId) {
    final index = state.indexWhere((item) => item.id == itemId);
    if (index == -1) return null;
    final deleted = state[index];
    state = List.from(state)..removeAt(index);
    return deleted;
  }

  /// Re-insert a previously deleted item at a specific index (undo).
  void restoreItem(BillItem item, int index) {
    final clamped = index.clamp(0, state.length);
    state = List.from(state)..insert(clamped, item);
  }

  /// Add a new item manually.
  void addItem(BillItem item) {
    state = [...state, item];
  }

  /// Update an existing item's name, price, or quantity.
  void updateItem(String itemId, {String? name, double? price, int? quantity}) {
    state = [
      for (final item in state)
        if (item.id == itemId)
          item.copyWith(name: name, price: price, quantity: quantity)
        else
          item,
    ];
  }

  /// When a new participant is added mid-review, add them to all items
  /// (spec: default is ALL participants assigned).
  void addParticipantToAllItems(String participantId) {
    assignToAll(participantId);
  }

  /// When a participant is removed entirely, strip them from all items.
  void removeParticipantFromAllItems(String participantId) {
    removeFromAll(participantId);
  }

  void clear() => state = [];
}

final billItemsProvider =
    StateNotifierProvider<BillItemsNotifier, List<BillItem>>(
  (ref) => BillItemsNotifier(),
);

/// Manages the bill-level totals (subtotal, tax, service charge, etc.).
class BillStateNotifier extends StateNotifier<BillState> {
  BillStateNotifier()
      : super(BillState(subtotal: 0, finalTotal: 0));

  void load(BillState bill) => state = bill;

  void updateSubtotal(double v) =>
      state = state.copyWith(subtotal: v);
  void updateTax(double v) =>
      state = state.copyWith(totalTax: v);
  void updateServiceCharge(double v) =>
      state = state.copyWith(serviceCharge: v);
  void updateDiscount(double v) =>
      state = state.copyWith(discount: v);
  void updateFinalTotal(double v) =>
      state = state.copyWith(finalTotal: v);

  void clear() =>
      state = BillState(subtotal: 0, finalTotal: 0);
}

final billStateProvider =
    StateNotifierProvider<BillStateNotifier, BillState>(
  (ref) => BillStateNotifier(),
);
