/// A record of a utility bill (electricity, water, or telecom) that the shop
/// paid to the provider on a customer's behalf — the way this actually works
/// in Sudan today: no provider exposes a public API, so the shop pays via its
/// own channel (cash errand, Bankak, etc.) and this is the paper trail.
class UtilityPayment {
  final int? id;
  final String utilityType; // 'Electricity' | 'Water' | 'Telecom'
  final String provider;
  final String accountNumber;
  final String? payerName;
  final String? payerPhone;
  final double billAmount;
  final double serviceFee;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final int createdBy;
  final String createdAt;

  const UtilityPayment({
    this.id,
    required this.utilityType,
    required this.provider,
    required this.accountNumber,
    this.payerName,
    this.payerPhone,
    required this.billAmount,
    this.serviceFee = 0,
    this.paymentMethod = 'Cash',
    this.reference,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  /// What the customer handed over: the bill amount plus the shop's fee.
  double get totalCollected => billAmount + serviceFee;

  factory UtilityPayment.fromMap(Map<String, dynamic> map) => UtilityPayment(
    id: map['id'] as int?,
    utilityType: map['utility_type'] as String,
    provider: map['provider'] as String,
    accountNumber: map['account_number'] as String,
    payerName: map['payer_name'] as String?,
    payerPhone: map['payer_phone'] as String?,
    billAmount: (map['bill_amount'] as num?)?.toDouble() ?? 0,
    serviceFee: (map['service_fee'] as num?)?.toDouble() ?? 0,
    paymentMethod: (map['payment_method'] as String?) ?? 'Cash',
    reference: map['reference'] as String?,
    notes: map['notes'] as String?,
    createdBy: map['created_by'] as int,
    createdAt: map['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'utility_type': utilityType,
    'provider': provider,
    'account_number': accountNumber,
    'payer_name': payerName,
    'payer_phone': payerPhone,
    'bill_amount': billAmount,
    'service_fee': serviceFee,
    'payment_method': paymentMethod,
    'reference': reference,
    'notes': notes,
    'created_by': createdBy,
    'is_synced': 0,
    'created_at': createdAt,
  };
}
