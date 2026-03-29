class BillItem {
  final String id;
  String name;
  double price; // Unit price
  int quantity; // Default 1
  List<String> assignedParticipantIds; // Default: ALL participants at load

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    List<String>? assignedParticipantIds,
  }) : assignedParticipantIds = assignedParticipantIds ?? [];

  double get effectiveTotalPrice => price * quantity;

  BillItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    List<String>? assignedParticipantIds,
  }) {
    return BillItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      assignedParticipantIds:
          assignedParticipantIds ?? List.from(this.assignedParticipantIds),
    );
  }

  /// Returns true if no participants are assigned (invalid state).
  bool get isUnassigned => assignedParticipantIds.isEmpty;
}
