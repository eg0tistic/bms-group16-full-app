import '../utils/formatters.dart';

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int customerId;
  final String? customerName;
  final int createdBy;
  final double totalAmount;
  final double taxAmount;
  final double taxRate;
  final String currency;
  final String? dueDate;
  final String? notes;
  final String status;
  final String? createdAt;

  const Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.customerName,
    required this.createdBy,
    this.totalAmount = 0,
    this.taxAmount = 0,
    this.taxRate = 0,
    this.currency = 'SDG',
    this.dueDate,
    this.notes,
    this.status = 'Draft',
    this.createdAt,
  });

  double get grandTotal => totalAmount + taxAmount;

  /// True when this is an unsettled credit sale whose due date has passed.
  bool get isOverdue {
    if (dueDate == null || dueDate!.isEmpty) return false;
    if (status == 'Paid' || status == 'Voided' || status == 'Closed') {
      return false;
    }
    final due = DateTime.tryParse(dueDate!);
    if (due == null) return false;
    final today = DateTime.now();
    final endOfDue = DateTime(due.year, due.month, due.day, 23, 59, 59);
    return endOfDue.isBefore(today);
  }

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
    id: map['id'] as int?,
    invoiceNumber: map['invoice_number'] as String,
    customerId: map['customer_id'] as int,
    customerName: map['customer_name'] as String?,
    createdBy: map['created_by'] as int,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
    taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
    currency: (map['currency'] as String?) ?? 'SDG',
    dueDate: map['due_date'] as String?,
    notes: map['notes'] as String?,
    status: (map['status'] as String?) ?? 'Draft',
    createdAt: map['created_at'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'invoice_number': invoiceNumber,
    'customer_id': customerId,
    'created_by': createdBy,
    'total_amount': totalAmount,
    'tax_amount': taxAmount,
    'tax_rate': taxRate,
    'currency': currency,
    'due_date': dueDate,
    'notes': notes,
    'status': status,
    'is_synced': 0,
    'created_at': createdAt ?? Fmt.now(),
    'updated_at': Fmt.now(),
  };

  Invoice copyWith({
    double? totalAmount,
    double? taxAmount,
    double? taxRate,
    String? currency,
    String? dueDate,
    String? status,
    String? notes,
  }) => Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    customerId: customerId,
    customerName: customerName,
    createdBy: createdBy,
    totalAmount: totalAmount ?? this.totalAmount,
    taxAmount: taxAmount ?? this.taxAmount,
    taxRate: taxRate ?? this.taxRate,
    currency: currency ?? this.currency,
    dueDate: dueDate ?? this.dueDate,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final int? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  const InvoiceItem({
    this.id,
    required this.invoiceId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
    id: map['id'] as int?,
    invoiceId: map['invoice_id'] as int,
    productId: map['product_id'] as int?,
    description: map['description'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unitPrice: (map['unit_price'] as num).toDouble(),
    subtotal: (map['subtotal'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'product_id': productId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'subtotal': subtotal,
    'created_at': Fmt.now(),
  };
}
