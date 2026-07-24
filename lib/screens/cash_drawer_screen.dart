import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../models/cash_drawer_session.dart';
import '../utils/app_strings.dart';
import '../utils/formatters.dart';
import '../utils/logger.dart';
import '../widgets/app_drawer.dart';

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen> {
  final _openingCtrl = TextEditingController();
  final _countedCtrl = TextEditingController();

  CashDrawerSession? _open;
  double _collected = 0;
  List<CashDrawerSession> _recent = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _countedCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = DatabaseHelper.instance;
      final open = await db.getOpenCashDrawer();
      final collected = open == null
          ? 0.0
          : await db.cashCollectedSince(open.openedAt);
      final recent = await db.getRecentCashDrawers();
      if (!mounted) return;
      setState(() {
        _open = open;
        _collected = collected;
        _recent = recent;
        _loading = false;
      });
    } catch (e, st) {
      logError('load cash drawer', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  String _s(String k) => AppStrings.get(k, context.read<AppState>().language);

  Future<void> _openDrawer() async {
    final opening = double.tryParse(
      _openingCtrl.text.trim().replaceAll(',', '.'),
    );
    if (opening == null || opening < 0) return;
    final userId = context.read<AppState>().currentUser?.id;
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.openCashDrawer(userId, opening);
      _openingCtrl.clear();
      await _load();
    } catch (e, st) {
      logError('open cash drawer', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s('operation_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeDrawer() async {
    final counted = double.tryParse(
      _countedCtrl.text.trim().replaceAll(',', '.'),
    );
    if (counted == null || counted < 0 || _open == null) return;
    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.closeCashDrawer(_open!, counted);
      _countedCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s('drawer_closed_msg'))));
      }
      await _load();
    } catch (e, st) {
      logError('close cash drawer', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s('operation_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    String s(String k) => AppStrings.get(k, lang);

    return Scaffold(
      appBar: AppBar(title: Text(s('cash_drawer_title'))),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (_open == null)
                  _OpenCard(
                    controller: _openingCtrl,
                    busy: _busy,
                    onOpen: _openDrawer,
                    lang: lang,
                  )
                else
                  _CloseCard(
                    session: _open!,
                    collected: _collected,
                    controller: _countedCtrl,
                    busy: _busy,
                    onClose: _closeDrawer,
                    lang: lang,
                  ),
                const SizedBox(height: 22),
                Text(
                  s('recent_sessions'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        s('no_drawer_sessions'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final session in _recent)
                    _SessionTile(session: session, lang: lang),
              ],
            ),
    );
  }
}

class _OpenCard extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onOpen;
  final String lang;

  const _OpenCard({
    required this.controller,
    required this.busy,
    required this.onOpen,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined, color: cs.secondary),
                const SizedBox(width: 10),
                Text(
                  s('open_drawer'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: s('opening_balance'),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onOpen,
              icon: const Icon(Icons.lock_open_outlined, size: 18),
              label: Text(s('open_drawer')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseCard extends StatelessWidget {
  final CashDrawerSession session;
  final double collected;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onClose;
  final String lang;

  const _CloseCard({
    required this.session,
    required this.collected,
    required this.controller,
    required this.busy,
    required this.onClose,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final expected = session.openingBalance + collected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s('drawer_open_status'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Line(label: s('opened_at'), value: Fmt.dateTime(session.openedAt)),
            _Line(
              label: s('opening_balance'),
              value: Fmt.currency(session.openingBalance),
            ),
            _Line(label: s('cash_collected'), value: Fmt.currency(collected)),
            const Divider(height: 22),
            _Line(
              label: s('expected_cash'),
              value: Fmt.currency(expected),
              emphasize: true,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: s('counted_cash'),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 10),
            // Live variance preview as the cashier types the counted amount.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final counted = double.tryParse(
                  value.text.trim().replaceAll(',', '.'),
                );
                if (counted == null) return const SizedBox.shrink();
                return _VarianceChip(variance: counted - expected, lang: lang);
              },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(s('close_drawer')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _Line({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                fontSize: emphasize ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VarianceChip extends StatelessWidget {
  final double variance;
  final String lang;

  const _VarianceChip({required this.variance, required this.lang});

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    final (Color color, String label) = variance == 0
        ? (cs.secondary, s('variance_balanced'))
        : variance > 0
        ? (Colors.green.shade700, s('variance_over'))
        : (cs.error, s('variance_short'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            variance == 0
                ? Icons.check_circle_outline
                : variance > 0
                ? Icons.trending_up
                : Icons.trending_down,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${s('variance')}: $label',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            Fmt.currency(variance.abs()),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final CashDrawerSession session;
  final String lang;

  const _SessionTile({required this.session, required this.lang});

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final variance = session.variance ?? 0;
    final color = session.isOpen
        ? cs.secondary
        : variance == 0
        ? cs.onSurfaceVariant
        : variance > 0
        ? Colors.green.shade700
        : cs.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                session.isOpen ? Icons.lock_open_outlined : Icons.lock_outline,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.dateTime(session.openedAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session.isOpen
                        ? s('drawer_open_status')
                        : '${s('expected_cash')}: ${Fmt.currency(session.expectedCash)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!session.isOpen)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s('variance'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    Fmt.currency(variance),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
