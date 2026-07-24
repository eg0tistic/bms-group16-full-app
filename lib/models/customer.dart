import '../utils/formatters.dart';

class Customer {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final double balance;
  final double creditLimit;
  final int isActive;
  final String? createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.balance = 0,
    this.creditLimit = 0,
    this.isActive = 1,
    this.createdAt,
  });

  /// True when the outstanding balance has reached or passed the credit limit
  /// (only meaningful when a limit is set).
  bool get isOverCreditLimit => creditLimit > 0 && balance >= creditLimit;

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as int?,
    name: map['name'] as String,
    phone: (map['phone'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    balance: (map['balance'] as num?)?.toDouble() ?? 0,
    creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
    isActive: (map['is_active'] as int?) ?? 1,
    createdAt: map['created_at'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'balance': balance,
    'credit_limit': creditLimit,
    'is_active': isActive,
    'is_synced': 0,
    'created_at': createdAt ?? Fmt.now(),
    'updated_at': Fmt.now(),
  };

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    double? balance,
    double? creditLimit,
    int? isActive,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    balance: balance ?? this.balance,
    creditLimit: creditLimit ?? this.creditLimit,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );
}
