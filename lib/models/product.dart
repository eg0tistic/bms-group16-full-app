import '../utils/formatters.dart';

class Product {
  final int? id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final int isActive;
  final String? createdAt;

  const Product({
    this.id,
    required this.name,
    this.category = '',
    required this.price,
    this.unit = '',
    this.isActive = 1,
    this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    category: (map['category'] as String?) ?? '',
    price: (map['price'] as num).toDouble(),
    unit: (map['unit'] as String?) ?? '',
    isActive: (map['is_active'] as int?) ?? 1,
    createdAt: map['created_at'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'price': price,
    'unit': unit,
    'is_active': isActive,
    'is_synced': 0,
    'created_at': createdAt ?? Fmt.now(),
    'updated_at': Fmt.now(),
  };

  Product copyWith({
    String? name,
    String? category,
    double? price,
    String? unit,
    int? isActive,
  }) => Product(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    price: price ?? this.price,
    unit: unit ?? this.unit,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );
}
