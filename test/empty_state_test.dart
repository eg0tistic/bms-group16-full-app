import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:group16_bms/widgets/empty_state.dart';

void main() {
  // Flutter's test framework reports RenderFlex overflow as a test failure, so
  // pumping the widget in a tight RTL viewport verifies it stays overflow-safe.
  Widget harness(Widget child, {required Size size}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('EmptyState renders in a small RTL viewport without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      harness(
        const EmptyState(
          icon: Icons.people_outline,
          title: 'لا يوجد عملاء بعد — أضف أول عميل للبدء',
        ),
        size: const Size(320, 480),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('عملاء'), findsOneWidget);
  });

  testWidgets('EmptyState action button fires onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'لا توجد منتجات',
          actionLabel: 'إضافة منتج',
          onAction: () => tapped = true,
        ),
        size: const Size(320, 480),
      ),
    );

    await tester.tap(find.text('إضافة منتج'));
    expect(tapped, isTrue);
  });
}
