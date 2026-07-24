import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../models/app_user.dart';
import '../utils/app_strings.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/responsive_content.dart';
import '../widgets/skeletons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _dailyRevenue = [];
  int _pendingSync = 0;
  String _lastSynced = '';
  String _storeName = AppConstants.defaultStoreName;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = DatabaseHelper.instance;
      final m = await db.getMetrics();
      final daily = await db.getDailyRevenueLast7Days();
      final ls = await db.getSetting(AppConstants.lastSyncedKey) ?? '';
      final ps = await db.getPendingSyncCount();
      final store = await db.getSetting(AppConstants.storeNameKey);
      if (mounted) {
        setState(() {
          _metrics = m;
          _dailyRevenue = daily;
          _lastSynced = ls;
          _pendingSync = ps;
          _storeName = store?.trim().isNotEmpty == true
              ? store!.trim()
              : AppConstants.defaultStoreName;
          _loadError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final user = state.currentUser;
    final m = _metrics;

    return Scaffold(
      appBar: AppBar(
        title: Text(s('home_title')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: _UserDot(user: user),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth > 1180
                ? (constraints.maxWidth - 1180) / 2 + 16
                : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 24),
              children: [
                _StoreHeader(user: user, storeName: _storeName, lang: lang),
                const SizedBox(height: 18),
                if (m == null && !_loadError) ...[
                  _SectionTitle(
                    title: lang == 'ar' ? 'ملخص الأعمال' : 'Business Summary',
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 12.0;
                      final columns = responsiveColumns(constraints.maxWidth);
                      final cardWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(
                          4,
                          (_) => SizedBox(
                            width: cardWidth,
                            child: const SkeletonKpiCard(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (_loadError) _ErrorCard(message: s('error')),
                if (m != null) ...[
                  _SectionTitle(
                    title: lang == 'ar' ? 'ملخص الأعمال' : 'Business Summary',
                  ),
                  const SizedBox(height: 10),
                  _KpiGrid(
                    items: [
                      _KpiData(
                        icon: Icons.payments_outlined,
                        label: s('today_revenue'),
                        rawValue: (m['today_revenue'] as num?)?.toDouble() ?? 0,
                        isAmount: true,
                        accent: AppTokens.teal,
                      ),
                      _KpiData(
                        icon: Icons.account_balance_wallet_outlined,
                        label: s('total_receivables'),
                        rawValue:
                            (m['total_receivables'] as num?)?.toDouble() ?? 0,
                        isAmount: true,
                        accent: AppTokens.gold,
                      ),
                      _KpiData(
                        icon: Icons.pending_actions_outlined,
                        label: s('unpaid_count'),
                        rawValue:
                            ((m['unpaid_count'] as num?)?.toDouble() ?? 0),
                        isAmount: false,
                        accent: AppTokens.clay,
                      ),
                      _KpiData(
                        icon: Icons.receipt_long_outlined,
                        label: s('invoices_count'),
                        rawValue:
                            ((m['invoices_count'] as num?)?.toDouble() ?? 0),
                        isAmount: false,
                        accent: cs.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle(title: s('revenue_last_7_days')),
                  const SizedBox(height: 10),
                  _RevenueMiniChart(rows: _dailyRevenue, lang: lang),
                ],
                const SizedBox(height: 22),
                _SectionTitle(title: s('quick_actions')),
                const SizedBox(height: 10),
                _QuickActions(
                  isAdmin: state.isAdmin,
                  newInvoiceLabel: s('new_invoice'),
                  addCustomerLabel: s('add_customer'),
                  addProductLabel: s('add_product'),
                ),
                const SizedBox(height: 22),
                _SyncStatusCard(
                  pendingCount: _pendingSync,
                  lastSynced: _lastSynced,
                  lang: lang,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  final AppUser? user;

  const _UserDot({this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user != null && user!.fullName.isNotEmpty
        ? user!.fullName.characters.first
        : '?';

    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final AppUser? user;
  final String storeName;
  final String lang;

  const _StoreHeader({
    required this.user,
    required this.storeName,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = user?.isAdmin == true
        ? AppStrings.get('admin_role', lang)
        : AppStrings.get('cashier_role', lang);
    final name = user?.fullName.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: AppTokens.hero,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTokens.shadowMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name != null && name.isNotEmpty
                            ? name
                            : AppStrings.get('home_title', lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiData> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = responsiveColumns(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (int i = 0; i < items.length; i++)
              SizedBox(
                width: cardWidth,
                child: _KpiCard(data: items[i], index: i),
              ),
          ],
        );
      },
    );
  }
}

class _KpiData {
  final IconData icon;
  final String label;
  final double rawValue;
  final bool isAmount;
  final Color accent;

  const _KpiData({
    required this.icon,
    required this.label,
    required this.rawValue,
    required this.isAmount,
    required this.accent,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final int index;

  const _KpiCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: data.rawValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        final display = data.isAmount
            ? Fmt.currency(value)
            : value.round().toString();
        return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: data.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(data.icon, color: data.accent, size: 20),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: data.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        display,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .animate(delay: (60 * index).ms)
            .fadeIn(duration: 320.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              duration: 320.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

class _RevenueMiniChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String lang;

  const _RevenueMiniChart({required this.rows, required this.lang});

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Last 7 calendar days, oldest → newest.
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );

    final totals = <String, double>{};
    for (final r in rows) {
      final key = r['day'] as String?;
      if (key != null) totals[key] = (r['total'] as num?)?.toDouble() ?? 0;
    }

    final values = days.map((d) => totals[_key(d)] ?? 0.0).toList();
    final maxVal = values.fold(0.0, (a, b) => b > a ? b : a);
    final total7 = values.fold(0.0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: total7 <= 0
            ? SizedBox(
                height: 96,
                child: Center(
                  child: Text(
                    AppStrings.get('no_revenue_yet', lang),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      Fmt.currency(total7),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < days.length; i++)
                          Expanded(
                            child: _Bar(
                              value: values[i],
                              maxValue: maxVal,
                              label: days[i].day.toString(),
                              isToday: i == days.length - 1,
                              color: cs.secondary,
                              mutedLabel: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final bool isToday;
  final Color color;
  final Color mutedLabel;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.isToday,
    required this.color,
    required this.mutedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final frac = maxValue <= 0 ? 0.0 : (value / maxValue);
    const maxBarHeight = 64.0;
    final target = (frac * maxBarHeight).clamp(
      value > 0 ? 4.0 : 0.0,
      maxBarHeight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, h, _) => Container(
              height: h,
              decoration: BoxDecoration(
                gradient: isToday ? AppTokens.bar : null,
                color: isToday ? null : color.withValues(alpha: 0.22),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(2),
                ),
                boxShadow: isToday ? AppTokens.glowTeal : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday ? color : mutedLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isAdmin;
  final String newInvoiceLabel;
  final String addCustomerLabel;
  final String addProductLabel;

  const _QuickActions({
    required this.isAdmin,
    required this.newInvoiceLabel,
    required this.addCustomerLabel,
    required this.addProductLabel,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        icon: Icons.receipt_long_outlined,
        label: newInvoiceLabel,
        route: '/invoices',
        accent: AppTokens.teal,
      ),
      if (isAdmin)
        _ActionData(
          icon: Icons.person_add_alt_outlined,
          label: addCustomerLabel,
          route: '/customers',
          accent: AppTokens.info,
        ),
      if (isAdmin)
        _ActionData(
          icon: Icons.add_business_outlined,
          label: addProductLabel,
          route: '/products',
          accent: AppTokens.warning,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              _ActionRow(data: actions[i]),
              if (i != actions.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final String route;
  final Color accent;

  const _ActionData({
    required this.icon,
    required this.label,
    required this.route,
    required this.accent,
  });
}

class _ActionRow extends StatelessWidget {
  final _ActionData data;

  const _ActionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: data.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(data.icon, color: data.accent, size: 21),
      ),
      title: Text(
        data.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left
            : Icons.chevron_right,
        color: cs.onSurfaceVariant,
      ),
      onTap: () => Navigator.pushNamed(context, data.route),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  final int pendingCount;
  final String lastSynced;
  final String lang;

  const _SyncStatusCard({
    required this.pendingCount,
    required this.lastSynced,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final hasSync = lastSynced.isNotEmpty;
    final pending = pendingCount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (pending ? const Color(0xFFB45309) : Colors.green)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                pending
                    ? Icons.sync_problem_outlined
                    : Icons.cloud_done_outlined,
                color: pending
                    ? const Color(0xFFB45309)
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s('sync_status'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasSync
                        ? '${s('last_synced')}: $lastSynced'
                        : pending
                        ? '$pendingCount ${s('pending_sync')}'
                        : s('sync_not_configured'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.error),
        ),
      ),
    );
  }
}
