import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../models/customer.dart';
import '../utils/app_strings.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import '../widgets/empty_state.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeletons.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _all = [];
  List<Customer> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getActiveCustomers();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_all)
        : _all
              .where(
                (c) =>
                    c.name.toLowerCase().contains(q) ||
                    c.phone.toLowerCase().contains(q),
              )
              .toList();
  }

  Future<void> _showForm({Customer? customer}) async {
    final lang = context.read<AppState>().language;
    final result = await showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerForm(lang: lang, existing: customer),
    );

    if (!mounted || result == null) return;

    final db = DatabaseHelper.instance;
    try {
      if (customer == null) {
        await db.insertCustomer(result);
      } else {
        await db.updateCustomer(result);
      }
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('customer_saved', lang))),
        );
      }
    } catch (e, st) {
      logError('save customer', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('operation_failed', lang))),
        );
      }
    }
  }

  Future<void> _deactivate(Customer customer) async {
    final lang = context.read<AppState>().language;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.get('deactivate_customer', lang)),
        content: Text(AppStrings.get('deactivate_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.get('confirm', lang)),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await DatabaseHelper.instance.deactivateCustomer(customer.id!);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('customer_deactivated', lang))),
        );
      }
    } catch (e, st) {
      logError('deactivate customer', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('operation_failed', lang))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    String s(String k) => AppStrings.get(k, lang);
    final isAdmin = state.isAdmin;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s('customers_title'))),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: s('search_customers'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(_applyFilter);
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surface,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 6)
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: s('no_customers'),
                    actionLabel: isAdmin ? s('add_customer') : null,
                    actionIcon: Icons.person_add,
                    onAction: isAdmin ? () => _showForm() : null,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _CustomerCard(
                        customer: _filtered[i],
                        lang: lang,
                        isAdmin: isAdmin,
                        onEdit: () => _showForm(customer: _filtered[i]),
                        onDeactivate: () => _deactivate(_filtered[i]),
                        onView: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CustomerStatementScreen(
                              customer: _filtered[i],
                              lang: lang,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.person_add),
              label: Text(s('add_customer')),
            )
          : null,
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final String lang;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onView;

  const _CustomerCard({
    required this.customer,
    required this.lang,
    required this.isAdmin,
    required this.onEdit,
    required this.onDeactivate,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final initial = customer.name.isNotEmpty
        ? customer.name.characters.first
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onView,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (customer.phone.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _InfoLine(
                          icon: Icons.phone_outlined,
                          text: customer.phone,
                        ),
                      ],
                      if (customer.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoLine(
                          icon: Icons.location_on_outlined,
                          text: customer.address,
                          maxLines: 2,
                        ),
                      ],
                      if (customer.balance > 0 || customer.creditLimit > 0) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (customer.balance > 0)
                              _BalanceBadge(
                                text:
                                    '${s('customer_balance')}: ${Fmt.currency(customer.balance)}',
                              ),
                            if (customer.creditLimit > 0)
                              _InfoBadge(
                                icon: Icons.credit_score_outlined,
                                text:
                                    '${s('credit_limit')}: ${Fmt.currency(customer.creditLimit)}',
                              ),
                            if (customer.isOverCreditLimit)
                              _WarnBadge(text: s('over_credit_limit')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isAdmin)
                  _CardMenu(
                    onEdit: onEdit,
                    onDeactivate: onDeactivate,
                    editLabel: s('edit'),
                    deactivateLabel: s('deactivate_customer'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerStatementScreen extends StatefulWidget {
  final Customer customer;
  final String lang;

  const _CustomerStatementScreen({required this.customer, required this.lang});

  @override
  State<_CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<_CustomerStatementScreen> {
  String _currency = 'SDG';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getCustomerStatement(
      widget.customer.id!,
      currency: _currency,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    final outstanding = _rows.fold<double>(
      0,
      (sum, r) => sum + ((r['remaining'] as num?)?.toDouble() ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'كشف حساب العميل' : 'Customer Statement'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (widget.customer.phone.isNotEmpty)
                      Text(widget.customer.phone),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${ar ? 'المستحق' : 'Outstanding'}: ${Fmt.currency(outstanding, _currency)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'SDG', label: Text('SDG')),
                            ButtonSegment(value: 'USD', label: Text('USD')),
                          ],
                          selected: {_currency},
                          onSelectionChanged: (v) {
                            setState(() {
                              _currency = v.first;
                              _loading = true;
                            });
                            _load();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  ar
                      ? 'لا توجد فواتير بهذه العملة'
                      : 'No invoices in this currency',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final row in _rows)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(row['invoice_number'] as String),
                    subtitle: Text(
                      '${Fmt.date(row['created_at'] as String?)} · ${row['status']}\n'
                      '${ar ? 'المدفوع' : 'Paid'}: ${Fmt.currency((row['paid'] as num).toDouble(), _currency)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      Fmt.currency(
                        (row['remaining'] as num).toDouble(),
                        _currency,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: (row['remaining'] as num) > 0
                            ? Theme.of(context).colorScheme.error
                            : Colors.green,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const _InfoLine({required this.icon, required this.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final String text;

  const _BalanceBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 14,
            color: cs.error,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.secondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarnBadge extends StatelessWidget {
  final String text;

  const _WarnBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_outlined, size: 14, color: cs.error),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: cs.error,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final String editLabel;
  final String deactivateLabel;

  const _CardMenu({
    required this.onEdit,
    required this.onDeactivate,
    required this.editLabel,
    required this.deactivateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: '',
      icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
      onSelected: (val) {
        if (val == 'edit') onEdit();
        if (val == 'deactivate') onDeactivate();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(editLabel)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'deactivate',
          child: Row(
            children: [
              Icon(Icons.person_off_outlined, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(deactivateLabel, style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add / Edit form ───────────────────────────────────────────────────────────

class _CustomerForm extends StatefulWidget {
  final String lang;
  final Customer? existing;

  const _CustomerForm({required this.lang, this.existing});

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _creditCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
    final limit = widget.existing?.creditLimit ?? 0;
    _creditCtrl = TextEditingController(
      text: limit > 0 ? limit.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final rawPhone = _phoneCtrl.text.trim();
    // Store the phone in normalized local form when present.
    final phone = rawPhone.isEmpty
        ? ''
        : (SudanPhone.normalize(rawPhone) ?? rawPhone);
    final creditLimit =
        double.tryParse(_creditCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      Customer(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        phone: phone,
        address: _addressCtrl.text.trim(),
        balance: widget.existing?.balance ?? 0,
        creditLimit: creditLimit,
        createdAt: widget.existing?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, widget.lang);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEditing ? s('edit_customer_title') : s('add_customer_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s('required_field')
                    : null,
                decoration: InputDecoration(
                  labelText: s('customer_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => SudanPhone.isValidOrEmpty(v ?? '')
                    ? null
                    : s('invalid_phone'),
                decoration: InputDecoration(
                  labelText: s('customer_phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s('customer_address'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _creditCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: s('credit_limit'),
                  prefixIcon: const Icon(Icons.credit_score_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(s('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
