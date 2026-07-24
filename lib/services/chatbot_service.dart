import '../data/database_helper.dart';
import '../utils/formatters.dart';

// ── Intent enum (file-private) ────────────────────────────────────────────────

enum _Intent {
  todayRevenue,
  totalRevenue,
  weekRevenue,
  monthRevenue,
  unpaidInvoices,
  customerCount,
  productCount,
  invoiceCount,
  topCustomers,
  topProducts,
  paymentMethods,
  howToInvoice,
  howToCustomer,
  howToPayment,
  help,
  unknown,
}

// ── Service ───────────────────────────────────────────────────────────────────

class ChatbotService {
  // Intents that require Admin role
  static const _adminOnly = {
    _Intent.todayRevenue,
    _Intent.totalRevenue,
    _Intent.weekRevenue,
    _Intent.monthRevenue,
    _Intent.topCustomers,
    _Intent.topProducts,
    _Intent.paymentMethods,
  };

  static String welcomeMessage(bool isArabic) {
    if (isArabic) {
      return 'مرحباً! أنا المساعد الذكي لنظام الفوترة.\n'
          'يمكنني مساعدتك في معرفة الإيرادات والعملاء\n'
          'والمنتجات وكيفية استخدام النظام.\n'
          'اسألني أو اختر سؤالاً من الأسفل.';
    } else {
      return 'Hello! I am the billing system assistant.\n'
          'I can help with revenue, customers, products,\n'
          'invoice status, and how to use the app.\n'
          'Ask me anything or pick a suggestion below.';
    }
  }

  static Future<String> getReply({
    required String message,
    required bool isAdmin,
    required bool isArabic,
  }) async {
    final normalized = message.toLowerCase().trim();
    if (normalized.isEmpty) return _unknownReply(isArabic);

    final intent = _detectIntent(normalized);

    if (!isAdmin && _adminOnly.contains(intent)) {
      return isArabic
          ? 'هذه المعلومات متاحة للمدير فقط.'
          : 'This information is available for Admin only.';
    }

    return _buildReply(intent, isArabic);
  }

  // ── Intent detection ───────────────────────────────────────────────────────

  static _Intent _detectIntent(String msg) {
    bool has(List<String> kw) => kw.any((k) => msg.contains(k));

    // 1. How-to questions
    if (has(['كيف', 'طريقة', 'خطوات', 'how to ', 'how do '])) {
      if (has(['فاتورة', 'invoice'])) return _Intent.howToInvoice;
      if (has(['عميل', 'زبون', 'customer'])) return _Intent.howToCustomer;
      if (has(['دفع', 'دفعة', 'payment', 'pay '])) return _Intent.howToPayment;
      return _Intent.help;
    }

    // 2. Greeting / general help
    if (has([
      'مرحبا',
      'أهلا',
      'اهلا',
      'مساعدة',
      'ساعدني',
      'السلام',
      'hello',
      'help me',
      'what can you',
      'good morning',
    ])) {
      return _Intent.help;
    }

    // 3. Revenue — time-specific variants first
    final hasRevKw = has([
      'دخل',
      'ايراد',
      'إيراد',
      'مبيعات',
      'revenue',
      'sales',
      'income',
      'earnings',
    ]);
    final hasToday = has(['اليوم', 'today']);
    final hasWeek = has(['اسبوع', 'أسبوع', 'الاسبوع', 'week', 'weekly']);
    final hasMonth = has(['شهر', 'الشهر', 'month', 'monthly']);
    final hasTotal = has([
      'اجمالي',
      'إجمالي',
      'كل المبيع',
      'total',
      'all sales',
      'all revenue',
    ]);

    if (hasRevKw || hasTotal || hasToday || hasWeek || hasMonth) {
      if (hasToday) return _Intent.todayRevenue;
      if (hasWeek) return _Intent.weekRevenue;
      if (hasMonth) return _Intent.monthRevenue;
      if (hasTotal) return _Intent.totalRevenue;
      return _Intent.todayRevenue; // bare revenue keyword → today
    }

    // 4. Top customers (before generic customer check)
    final hasTopKw = has([
      'اعلى',
      'أعلى',
      'اكثر',
      'أكثر',
      'افضل',
      'أفضل',
      'top',
      'highest',
      'best',
      'most',
    ]);
    if (hasTopKw &&
        has(['عميل', 'عملاء', 'زبون', 'زبائن', 'customer', 'customers'])) {
      return _Intent.topCustomers;
    }

    // 5. Top products (before generic product check)
    if (hasTopKw &&
        has([
          'منتج',
          'منتجات',
          'خدمة',
          'خدمات',
          'مبيع',
          'product',
          'products',
          'item',
          'service',
          'selling',
        ])) {
      return _Intent.topProducts;
    }

    // 6. Unpaid / receivables
    if (has([
      'غير مدفوع',
      'مديون',
      'مديونية',
      'مستحق',
      'متبقي',
      'مستحقات',
      'unpaid',
      'receivable',
      'outstanding',
      'owing',
      'overdue',
    ])) {
      return _Intent.unpaidInvoices;
    }

    // 7. Payment methods
    if (has([
      'طريقة دفع',
      'طرق دفع',
      'بنكك',
      'كاشي',
      'بيدي',
      'حوالة',
      'payment method',
      'bankak',
      'cashi',
      'bede',
      'hawala',
      'bank transfer',
      'cash payment',
    ])) {
      return _Intent.paymentMethods;
    }

    // 8. Customers
    if (has([
      'عميل',
      'عملاء',
      'زبون',
      'زبائن',
      'customer',
      'customers',
      'client',
      'clients',
    ])) {
      return _Intent.customerCount;
    }

    // 9. Products
    if (has([
      'منتج',
      'منتجات',
      'خدمة',
      'خدمات',
      'product',
      'products',
      'service',
      'item',
      'items',
    ])) {
      return _Intent.productCount;
    }

    // 10. Invoices / invoice status
    if (has([
      'فاتورة',
      'فواتير',
      'مدفوعة',
      'مؤكدة',
      'مسودة',
      'ملغاة',
      'invoice',
      'invoices',
      'bill',
      'bills',
      'paid invoice',
      'confirmed',
      'draft',
    ])) {
      return _Intent.invoiceCount;
    }

    return _Intent.unknown;
  }

  // ── Reply builder ──────────────────────────────────────────────────────────

  static Future<String> _buildReply(_Intent intent, bool isArabic) async {
    final summaryIntents = {
      _Intent.todayRevenue,
      _Intent.totalRevenue,
      _Intent.weekRevenue,
      _Intent.monthRevenue,
      _Intent.unpaidInvoices,
      _Intent.customerCount,
      _Intent.productCount,
      _Intent.invoiceCount,
    };

    if (summaryIntents.contains(intent)) {
      final data = await DatabaseHelper.instance.getReportSummary();
      return _summaryReply(intent, data, isArabic);
    }
    if (intent == _Intent.topCustomers) {
      final rows = await DatabaseHelper.instance.getTopCustomersByBalance();
      return _topCustomersReply(rows, isArabic);
    }
    if (intent == _Intent.topProducts) {
      final rows = await DatabaseHelper.instance.getTopProducts(limit: 5);
      return _topProductsReply(rows, isArabic);
    }
    if (intent == _Intent.paymentMethods) {
      final rows = await DatabaseHelper.instance.getRevenueByMethod();
      return _paymentMethodsReply(rows, isArabic);
    }

    return switch (intent) {
      _Intent.howToInvoice => _howToInvoice(isArabic),
      _Intent.howToCustomer => _howToCustomer(isArabic),
      _Intent.howToPayment => _howToPayment(isArabic),
      _Intent.help => _helpReply(isArabic),
      _ => _unknownReply(isArabic),
    };
  }

  // ── Summary replies ────────────────────────────────────────────────────────

  static String _summaryReply(
    _Intent intent,
    Map<String, dynamic> data,
    bool ar,
  ) {
    final todayRev = (data['today_revenue'] as num).toDouble();
    final totalRev = (data['total_revenue'] as num).toDouble();
    final weekRev = (data['week_revenue'] as num).toDouble();
    final monthRev = (data['month_revenue'] as num).toDouble();
    final receivables = (data['unpaid_receivables'] as num).toDouble();
    final statusCounts =
        (data['status_counts'] as Map?)?.cast<String, int>() ?? {};
    final custCount = data['customers_count'] as int;
    final prodCount = data['products_count'] as int;
    final invCount = data['invoices_count'] as int;

    if (ar) {
      return switch (intent) {
        _Intent.todayRevenue =>
          todayRev == 0
              ? 'لم تسجَّل أي مدفوعات اليوم بعد.'
              : 'إيرادات اليوم: ${Fmt.currency(todayRev)}',
        _Intent.totalRevenue =>
          totalRev == 0
              ? 'لا توجد إيرادات مسجلة بعد.'
              : 'إجمالي الإيرادات: ${Fmt.currency(totalRev)}',
        _Intent.weekRevenue =>
          weekRev == 0
              ? 'لم تسجَّل أي مدفوعات هذا الأسبوع بعد.'
              : 'إيرادات هذا الأسبوع: ${Fmt.currency(weekRev)}',
        _Intent.monthRevenue =>
          monthRev == 0
              ? 'لم تسجَّل أي مدفوعات هذا الشهر بعد.'
              : 'إيرادات هذا الشهر: ${Fmt.currency(monthRev)}',
        _Intent.unpaidInvoices =>
          receivables == 0
              ? 'لا توجد مستحقات غير مدفوعة. جميع الحسابات مسوّاة.'
              : 'إجمالي المستحقات: ${Fmt.currency(receivables)}\n'
                    'فواتير مؤكدة غير مدفوعة: ${statusCounts['Confirmed'] ?? 0}',
        _Intent.customerCount => 'عدد العملاء النشطين: $custCount',
        _Intent.productCount => 'عدد المنتجات والخدمات: $prodCount',
        _Intent.invoiceCount =>
          'إجمالي الفواتير: $invCount\n'
              '- مدفوعة: ${statusCounts['Paid'] ?? 0}\n'
              '- مؤكدة: ${statusCounts['Confirmed'] ?? 0}\n'
              '- مسودة: ${statusCounts['Draft'] ?? 0}\n'
              '- ملغاة: ${statusCounts['Voided'] ?? 0}',
        _ => _unknownReply(ar),
      };
    } else {
      return switch (intent) {
        _Intent.todayRevenue =>
          todayRev == 0
              ? 'No payments recorded today yet.'
              : "Today's revenue: ${Fmt.currency(todayRev)}",
        _Intent.totalRevenue =>
          totalRev == 0
              ? 'No revenue recorded yet.'
              : 'Total revenue: ${Fmt.currency(totalRev)}',
        _Intent.weekRevenue =>
          weekRev == 0
              ? 'No payments this week yet.'
              : "This week's revenue: ${Fmt.currency(weekRev)}",
        _Intent.monthRevenue =>
          monthRev == 0
              ? 'No payments this month yet.'
              : "This month's revenue: ${Fmt.currency(monthRev)}",
        _Intent.unpaidInvoices =>
          receivables == 0
              ? 'No outstanding receivables. All accounts are settled.'
              : 'Total receivables: ${Fmt.currency(receivables)}\n'
                    'Confirmed unpaid invoices: ${statusCounts['Confirmed'] ?? 0}',
        _Intent.customerCount => 'Active customers: $custCount',
        _Intent.productCount => 'Active products / services: $prodCount',
        _Intent.invoiceCount =>
          'Total invoices: $invCount\n'
              '- Paid: ${statusCounts['Paid'] ?? 0}\n'
              '- Confirmed: ${statusCounts['Confirmed'] ?? 0}\n'
              '- Draft: ${statusCounts['Draft'] ?? 0}\n'
              '- Voided: ${statusCounts['Voided'] ?? 0}',
        _ => _unknownReply(ar),
      };
    }
  }

  // ── List replies ───────────────────────────────────────────────────────────

  static String _topCustomersReply(List<Map<String, dynamic>> rows, bool ar) {
    if (rows.isEmpty) {
      return ar
          ? 'لا يوجد عملاء لديهم رصيد مستحق حالياً.'
          : 'No customers have outstanding balances currently.';
    }
    final buf = StringBuffer(
      ar
          ? 'أعلى العملاء من حيث الرصيد المستحق:\n'
          : 'Top customers by balance:\n',
    );
    for (int i = 0; i < rows.length; i++) {
      final name = rows[i]['name'] as String? ?? '';
      final balance = (rows[i]['balance'] as num).toDouble();
      buf.writeln('${i + 1}. $name — ${Fmt.currency(balance)}');
    }
    return buf.toString().trim();
  }

  static String _topProductsReply(List<Map<String, dynamic>> rows, bool ar) {
    if (rows.isEmpty) {
      return ar
          ? 'لا توجد مبيعات مسجلة بعد.'
          : 'No product sales recorded yet.';
    }
    final buf = StringBuffer(
      ar ? 'أكثر المنتجات مبيعاً:\n' : 'Top selling products:\n',
    );
    for (int i = 0; i < rows.length; i++) {
      final name = rows[i]['description'] as String? ?? '';
      final qty = _qtyStr((rows[i]['total_qty'] as num?)?.toDouble() ?? 0);
      final rev = (rows[i]['total_revenue'] as num?)?.toDouble() ?? 0;
      if (ar) {
        buf.writeln(
          '${i + 1}. $name — الكمية: $qty، المبيعات: ${Fmt.currency(rev)}',
        );
      } else {
        buf.writeln('${i + 1}. $name — Qty: $qty, Sales: ${Fmt.currency(rev)}');
      }
    }
    return buf.toString().trim();
  }

  static String _paymentMethodsReply(List<Map<String, dynamic>> rows, bool ar) {
    if (rows.isEmpty) {
      return ar ? 'لا توجد مدفوعات مسجلة بعد.' : 'No payments recorded yet.';
    }
    final buf = StringBuffer(
      ar ? 'إجمالي المدفوعات حسب الطريقة:\n' : 'Total payments by method:\n',
    );
    for (final m in rows) {
      final method = m['method'] as String;
      final total = (m['total'] as num).toDouble();
      buf.writeln('- ${_localizeMethod(method, ar)}: ${Fmt.currency(total)}');
    }
    return buf.toString().trim();
  }

  // ── How-to replies ─────────────────────────────────────────────────────────

  static String _howToInvoice(bool ar) => ar
      ? 'لإنشاء فاتورة جديدة:\n'
            '1. افتح قسم "الفواتير" من القائمة.\n'
            '2. اضغط زر + لإنشاء فاتورة.\n'
            '3. اختر العميل.\n'
            '4. أضف المنتجات والكميات.\n'
            '5. اضغط "تأكيد الفاتورة" أو "حفظ كمسودة".'
      : 'To create a new invoice:\n'
            '1. Open Invoices from the side menu.\n'
            '2. Tap the + button.\n'
            '3. Select a customer.\n'
            '4. Add products and quantities.\n'
            '5. Tap "Confirm Invoice" or "Save as Draft".';

  static String _howToCustomer(bool ar) => ar
      ? 'لإضافة عميل جديد:\n'
            '1. افتح قسم "العملاء" من القائمة.\n'
            '2. اضغط زر + لإضافة عميل.\n'
            '3. أدخل الاسم ورقم الهاتف.\n'
            '4. اضغط "حفظ".'
      : 'To add a new customer:\n'
            '1. Open Customers from the side menu.\n'
            '2. Tap the + button.\n'
            '3. Enter name and phone number.\n'
            '4. Tap "Save".';

  static String _howToPayment(bool ar) => ar
      ? 'لتسجيل دفعة على فاتورة:\n'
            '1. افتح قسم "الفواتير".\n'
            '2. اختر الفاتورة المراد الدفع عليها.\n'
            '3. اضغط "تسجيل دفعة".\n'
            '4. أدخل المبلغ وطريقة الدفع.\n'
            '5. اضغط "حفظ".'
      : 'To record a payment on an invoice:\n'
            '1. Open Invoices.\n'
            '2. Tap the invoice you want to pay.\n'
            '3. Tap "Record Payment".\n'
            '4. Enter amount and payment method.\n'
            '5. Tap "Save".';

  // ── Help / fallback replies ────────────────────────────────────────────────

  static String _helpReply(bool ar) => ar
      ? 'مرحباً! يمكنني مساعدتك في:\n'
            '- الإيرادات (اليوم / الأسبوع / الشهر / الإجمالي)\n'
            '- الفواتير غير المدفوعة\n'
            '- أكثر المنتجات مبيعاً\n'
            '- أعلى العملاء رصيداً\n'
            '- طرق الدفع\n'
            '- كيفية استخدام النظام\n\n'
            'اسألني أو اختر سؤالاً من الأسفل.'
      : 'Hello! I can help with:\n'
            '- Revenue (today / week / month / total)\n'
            '- Unpaid invoices & receivables\n'
            '- Top selling products\n'
            '- Top customers by balance\n'
            '- Payment method totals\n'
            '- How to use the app\n\n'
            'Ask me or pick a suggestion below.';

  static String _unknownReply(bool ar) => ar
      ? 'لم أفهم سؤالك. يمكنني مساعدتك في:\n'
            '- دخل اليوم\n'
            '- الفواتير غير المدفوعة\n'
            '- أكثر المنتجات مبيعاً\n'
            '- أكثر العملاء مديونية\n'
            '- كيف أعمل فاتورة؟'
      : "I didn't understand that. I can help with:\n"
            '- Today revenue\n'
            '- Unpaid invoices\n'
            '- Top products\n'
            '- Top customers\n'
            '- How to create an invoice?';

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _localizeMethod(String method, bool ar) {
    if (!ar) return method;
    return switch (method) {
      'Cash' => 'نقداً',
      'Bankak' => 'بنكك',
      'Bede' => 'بيدي',
      'Cashi' => 'كاشي',
      'Bank Transfer' => 'تحويل بنكي',
      'Hawala' => 'حوالة',
      _ => method,
    };
  }

  static String _qtyStr(double qty) => qty == qty.truncateToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(2);
}
