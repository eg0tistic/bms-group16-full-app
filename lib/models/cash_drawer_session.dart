import '../utils/formatters.dart';

/// A daily cash-drawer reconciliation session: opened with a starting float,
/// closed with the physically counted cash. Variance = counted − expected,
/// where expected = opening float + cash collected during the session.
class CashDrawerSession {
  final int? id;
  final int openedBy;
  final double openingBalance;
  final double expectedCash;
  final double? closingBalance;
  final double? variance;
  final String status; // 'Open' | 'Closed'
  final String openedAt;
  final String? closedAt;
  final String? notes;

  const CashDrawerSession({
    this.id,
    required this.openedBy,
    required this.openingBalance,
    this.expectedCash = 0,
    this.closingBalance,
    this.variance,
    this.status = 'Open',
    required this.openedAt,
    this.closedAt,
    this.notes,
  });

  bool get isOpen => status == 'Open';

  factory CashDrawerSession.fromMap(Map<String, dynamic> map) =>
      CashDrawerSession(
        id: map['id'] as int?,
        openedBy: map['opened_by'] as int,
        openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
        expectedCash: (map['expected_cash'] as num?)?.toDouble() ?? 0,
        closingBalance: (map['closing_balance'] as num?)?.toDouble(),
        variance: (map['variance'] as num?)?.toDouble(),
        status: (map['status'] as String?) ?? 'Open',
        openedAt: map['opened_at'] as String,
        closedAt: map['closed_at'] as String?,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'opened_by': openedBy,
    'opening_balance': openingBalance,
    'expected_cash': expectedCash,
    'closing_balance': closingBalance,
    'variance': variance,
    'status': status,
    'opened_at': openedAt,
    'closed_at': closedAt,
    'notes': notes,
    'is_synced': 0,
    'created_at': Fmt.now(),
  };
}
