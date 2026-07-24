import 'package:flutter_test/flutter_test.dart';
import 'package:group16_bms/models/customer.dart';
import 'package:group16_bms/models/invoice.dart';

String _isoDaysFromNow(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().split('T')[0];

void main() {
  Invoice invoice({String? dueDate, String status = 'Confirmed'}) => Invoice(
    invoiceNumber: 'INV-0001',
    customerId: 1,
    createdBy: 1,
    status: status,
    dueDate: dueDate,
  );

  group('Invoice.isOverdue', () {
    test('no due date is never overdue', () {
      expect(invoice(dueDate: null).isOverdue, isFalse);
      expect(invoice(dueDate: '').isOverdue, isFalse);
    });

    test('past due date on an unsettled invoice is overdue', () {
      expect(invoice(dueDate: _isoDaysFromNow(-2)).isOverdue, isTrue);
    });

    test('future due date is not overdue', () {
      expect(invoice(dueDate: _isoDaysFromNow(5)).isOverdue, isFalse);
    });

    test('paid invoice is never overdue even if past due', () {
      expect(
        invoice(dueDate: _isoDaysFromNow(-2), status: 'Paid').isOverdue,
        isFalse,
      );
    });
  });

  group('Customer.isOverCreditLimit', () {
    test('no limit set is never over limit', () {
      expect(
        const Customer(name: 'A', balance: 9999).isOverCreditLimit,
        isFalse,
      );
    });

    test('balance at or above limit is over limit', () {
      expect(
        const Customer(
          name: 'A',
          balance: 1000,
          creditLimit: 1000,
        ).isOverCreditLimit,
        isTrue,
      );
    });

    test('balance below limit is within limit', () {
      expect(
        const Customer(
          name: 'A',
          balance: 400,
          creditLimit: 1000,
        ).isOverCreditLimit,
        isFalse,
      );
    });
  });
}
