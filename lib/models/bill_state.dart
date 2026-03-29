class BillState {
  double subtotal;
  double totalTax;
  double serviceCharge;
  double discount;
  double finalTotal; // Ultimate source of truth
  String currency;

  BillState({
    required this.subtotal,
    this.totalTax = 0,
    this.serviceCharge = 0,
    this.discount = 0,
    required this.finalTotal,
    this.currency = 'INR',
  });

  BillState copyWith({
    double? subtotal,
    double? totalTax,
    double? serviceCharge,
    double? discount,
    double? finalTotal,
    String? currency,
  }) {
    return BillState(
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discount: discount ?? this.discount,
      finalTotal: finalTotal ?? this.finalTotal,
      currency: currency ?? this.currency,
    );
  }

  /// Recalculate what the final total should be from components.
  double get calculatedFinalTotal =>
      subtotal - discount + serviceCharge + totalTax;
}
