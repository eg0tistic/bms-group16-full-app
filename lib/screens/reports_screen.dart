import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../utils/app_strings.dart';
import '../utils/formatters.dart';
import '../utils/logger.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_content.dart';

// ── Data holder ───────────────────────────────────────────────────────────────

class _ReportData {
  final double totalRevenue;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double unpaidReceivables;
  final Map<String, int> statusCounts;
  final int customersCount;
  final int productsCount;
  final int invoicesCount;
  final double utilityServiceRevenue;
  final List<Map<String, dynamic>> paymentMethods;
  final List<Map<String, dynamic>> topCustomers;
  final List<Map<String, dynamic>> topProducts;

  _ReportData({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.unpaidReceivables,
    required this.statusCounts,
    required this.customersCount,
    required this.productsCount,
    required this.invoicesCount,
    required this.utilityServiceRevenue,
    required this.paymentMethods,
    required this.topCustomers,
    required this.topProducts,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  bool _loadError = false;
  _ReportData? _data;
  String _currency = 'SDG';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }
    final db = DatabaseHelper.instance;

    try {
      final results = await Future.wait([
        db.getReportSummary(currency: _currency),
        db.getRevenueByMethod(currency: _currency),
        db.getTopCustomersByBalance(currency: _currency),
        db.getTopProducts(limit: 5, currency: _currency),
      ]);

      if (!mounted) return;
      final summary = results[0] as Map<String, dynamic>;
      final methods = results[1] as List<Map<String, dynamic>>;
      final customers = results[2] as List<Map<String, dynamic>>;
      final products = results[3] as List<Map<String, dynamic>>;

      setState(() {
        _data = _ReportData(
          totalRevenue: (summary['total_revenue'] as num).toDouble(),
          todayRevenue: (summary['today_revenue'] as num).toDouble(),
          weekRevenue: (summary['week_revenue'] as num).toDouble(),
          monthRevenue: (summary['month_revenue'] as num).toDouble(),
          unpaidReceivables: (summary['unpaid_receivables'] as num).toDouble(),
          statusCounts: Map<String, int>.from(
            (summary['status_counts'] as Map?) ?? {},
          ),
          customersCount: summary['customers_count'] as int,
          productsCount: summary['products_count'] as int,
          invoicesCount: summary['invoices_count'] as int,
          utilityServiceRevenue:
              (summary['utility_service_revenue'] as num?)?.toDouble() ?? 0,
          paymentMethods: methods,
          topCustomers: customers,
          topProducts: products,
        );
        _loading = false;
      });
    } catch (e, st) {
      logError('load reports', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    if (!state.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(s('reports_title'))),
        drawer: const AppDrawer(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: cs.outline),
              const SizedBox(height: 16),
              Text(
                s('admin_only'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s('reports_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s('refresh'),
            onPressed: _load,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError
          ? EmptyState(
              icon: Icons.query_stats_outlined,
              title: s('operation_failed'),
              actionLabel: s('refresh'),
              actionIcon: Icons.refresh,
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'SDG', label: Text('SDG')),
                                ButtonSegment(value: 'USD', label: Text('USD')),
                              ],
                              selected: {_currency},
                              onSelectionChanged: (v) {
                                setState(() => _currency = v.first);
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSummaryCards(context, s, cs),
                          const SizedBox(height: 20),
                          _buildRevenueSection(context, s, cs),
                          const SizedBox(height: 20),
                          _buildStatusSection(context, s, cs),
                          const SizedBox(height: 20),
                          _buildPaymentMethods(context, s, cs),
                          const SizedBox(height: 20),
                          _buildTopCustomers(context, s, cs),
                          const SizedBox(height: 20),
                          _buildTopProducts(context, s, cs),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── 1. Summary cards ───────────────────────────────────────────────────────

  Widget _buildSummaryCards(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final d = _data!;
    final cards = [
      _CardInfo(
        label: s('today_revenue'),
        value: Fmt.currency(d.todayRevenue, _currency),
        icon: Icons.today_outlined,
        color: cs.primary,
      ),
      _CardInfo(
        label: s('total_revenue'),
        value: Fmt.currency(d.totalRevenue, _currency),
        icon: Icons.trending_up,
        color: Colors.green.shade700,
      ),
      _CardInfo(
        label: s('total_receivables'),
        value: Fmt.currency(d.unpaidReceivables, _currency),
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.orange.shade700,
      ),
      _CardInfo(
        label: s('invoices_count'),
        value: d.invoicesCount.toString(),
        icon: Icons.receipt_long_outlined,
        color: Colors.indigo.shade600,
      ),
      _CardInfo(
        label: s('customers_count'),
        value: d.customersCount.toString(),
        icon: Icons.people_outline,
        color: Colors.teal.shade600,
      ),
      _CardInfo(
        label: s('products_count'),
        value: d.productsCount.toString(),
        icon: Icons.inventory_2_outlined,
        color: Colors.purple.shade600,
      ),
      _CardInfo(
        label: s('paid_invoices'),
        value: (d.statusCounts['Paid'] ?? 0).toString(),
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
      ),
      _CardInfo(
        label: s('confirmed_invoices'),
        value: (d.statusCounts['Confirmed'] ?? 0).toString(),
        icon: Icons.pending_outlined,
        color: Colors.amber.shade700,
      ),
      _CardInfo(
        label: s('utility_service_revenue'),
        value: Fmt.currency(d.utilityServiceRevenue, 'SDG'),
        icon: Icons.bolt_outlined,
        color: Colors.deepOrange.shade600,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('summary')),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsiveColumns(constraints.maxWidth),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 140,
              ),
              itemCount: cards.length - 1,
              itemBuilder: (_, i) => _SmallMetricCard(info: cards[i]),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 132,
          child: _SmallMetricCard(info: cards.last),
        ),
      ],
    );
  }

  // ── 2. Revenue section ─────────────────────────────────────────────────────

  Widget _buildRevenueSection(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final d = _data!;
    final maxVal = [
      d.todayRevenue,
      d.weekRevenue,
      d.monthRevenue,
    ].fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('revenue_summary')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _RevenueBar(
                  label: s('today_revenue'),
                  amount: d.todayRevenue,
                  max: maxVal,
                  color: cs.primary,
                  currency: _currency,
                ),
                const SizedBox(height: 14),
                _RevenueBar(
                  label: s('this_week'),
                  amount: d.weekRevenue,
                  max: maxVal,
                  color: Colors.teal.shade600,
                  currency: _currency,
                ),
                const SizedBox(height: 14),
                _RevenueBar(
                  label: s('this_month'),
                  amount: d.monthRevenue,
                  max: maxVal,
                  color: Colors.indigo.shade600,
                  currency: _currency,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Invoice status breakdown ────────────────────────────────────────────

  Widget _buildStatusSection(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final d = _data!;
    final statuses = [
      _StatusInfo('Draft', s('status_draft'), Colors.grey.shade600),
      _StatusInfo('Confirmed', s('status_confirmed'), Colors.blue.shade700),
      _StatusInfo('Paid', s('status_paid'), Colors.green.shade700),
      _StatusInfo('Voided', s('status_voided'), Colors.red.shade700),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('invoice_status_breakdown')),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 92,
              ),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final st = statuses[index];
                final count = d.statusCounts[st.status] ?? 0;
                return Card(
                  elevation: 0,
                  color: st.color.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: st.color.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    child: Column(
                      children: [
                        Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: st.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          st.label,
                          style: TextStyle(fontSize: 11, color: st.color),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── 4. Payment methods ─────────────────────────────────────────────────────

  Widget _buildPaymentMethods(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final methods = _data!.paymentMethods;

    String methodLabel(String method) => switch (method) {
      'Cash' => s('method_cash'),
      'Bankak' => s('method_bankak'),
      'Bede' => s('method_bede'),
      'Cashi' => s('method_cashi'),
      'Bank Transfer' => s('method_bank_transfer'),
      'Hawala' => s('method_hawala'),
      _ => method,
    };

    final activeData =
        methods.where((m) => (m['total'] as num? ?? 0) > 0).toList()..sort(
          (a, b) =>
              ((b['total'] as num? ?? 0)).compareTo((a['total'] as num? ?? 0)),
        );

    final maxTotal = activeData.isEmpty
        ? 1.0
        : (activeData.first['total'] as num).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('payment_methods_summary')),
        Card(
          child: activeData.isEmpty
              ? _EmptyRow(label: s('no_report_data'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: activeData.map((md) {
                      final total = (md['total'] as num).toDouble();
                      final fraction = maxTotal > 0 ? total / maxTotal : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  methodLabel(md['method'] as String),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  Fmt.currency(total, _currency),
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 8,
                                backgroundColor: cs.surfaceContainerHighest,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // ── 5. Top customers ───────────────────────────────────────────────────────

  Widget _buildTopCustomers(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final customers = _data!.topCustomers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('top_customers')),
        Card(
          child: customers.isEmpty
              ? _EmptyRow(label: s('no_report_data'))
              : Column(
                  children: [
                    for (int i = 0; i < customers.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(customers[i]['name'] as String? ?? ''),
                        subtitle:
                            customers[i]['phone'] != null &&
                                (customers[i]['phone'] as String).isNotEmpty
                            ? Text(customers[i]['phone'] as String)
                            : null,
                        trailing: Text(
                          Fmt.currency(
                            (customers[i]['balance'] as num).toDouble(),
                            _currency,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ── 6. Top products ────────────────────────────────────────────────────────

  Widget _buildTopProducts(
    BuildContext context,
    String Function(String) s,
    ColorScheme cs,
  ) {
    final products = _data!.topProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s('top_products_report')),
        Card(
          child: products.isEmpty
              ? _EmptyRow(label: s('no_report_data'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              s('product_name'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              s('qty_sold'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              s('sales_amount'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    for (int i = 0; i < products.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: cs.secondaryContainer,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      products[i]['description'] as String? ??
                                          '',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                _qtyStr(
                                  (products[i]['total_qty'] as num?)
                                          ?.toDouble() ??
                                      0,
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 88,
                              child: Text(
                                Fmt.currency(
                                  (products[i]['total_revenue'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  _currency,
                                ),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CardInfo {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _CardInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatusInfo {
  final String status;
  final String label;
  final Color color;

  const _StatusInfo(this.status, this.label, this.color);
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  final _CardInfo info;

  const _SmallMetricCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTokens.rSm),
              ),
              child: Icon(info.icon, color: info.color, size: 19),
            ),
            const Spacer(),
            Text(
              info.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: info.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              info.label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  final String label;
  final double amount;
  final double max;
  final Color color;
  final String currency;

  const _RevenueBar({
    required this.label,
    required this.amount,
    required this.max,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? (amount / max).clamp(0.0, 1.0) : 0.0;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              Fmt.currency(amount, currency),
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: cs.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String label;

  const _EmptyRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

String _qtyStr(double qty) => qty == qty.truncateToDouble()
    ? qty.toInt().toString()
    : qty.toStringAsFixed(2);
