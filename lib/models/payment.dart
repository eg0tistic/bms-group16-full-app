import '../utils/formatters.dart';

class Payment {
  final int? id;
  final int invoiceId;
  final double amountPaid;
  final String paymentDate;
  final String method;
  final String? notes;
  final String? createdAt;
  final String? reversedAt;
  final int? reversedBy;
  final String? reversalReason;

  const Payment({
    this.id,
    required this.invoiceId,
    required this.amountPaid,
    required this.paymentDate,
    this.method = 'Cash',
    this.notes,
    this.createdAt,
    this.reversedAt,
    this.reversedBy,
    this.reversalReason,
  });

  bool get isReversed => reversedAt?.isNotEmpty == true;

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'] as int?,
    invoiceId: map['invoice_id'] as int,
    amountPaid: (map['amount_paid'] as num).toDouble(),
    paymentDate: map['payment_date'] as String,
    method: (map['method'] as String?) ?? 'Cash',
    notes: map['notes'] as String?,
    createdAt: map['created_at'] as String?,
    reversedAt: map['reversed_at'] as String?,
    reversedBy: map['reversed_by'] as int?,
    reversalReason: map['reversal_reason'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'amount_paid': amountPaid,
    'payment_date': paymentDate,
    'method': method,
    'notes': notes,
    'is_synced': 0,
    'created_at': createdAt ?? Fmt.now(),
    'reversed_at': reversedAt,
    'reversed_by': reversedBy,
    'reversal_reason': reversalReason,
  };
}
