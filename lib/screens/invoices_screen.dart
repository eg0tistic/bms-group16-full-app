import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:printing/printing.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../utils/app_strings.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeletons.dart';

// ── Top-level helpers ─────────────────────────────────────────────────────────

String _statusLabel(String status, String lang) {
  final key = switch (status) {
    'Draft' => 'status_draft',
    'Confirmed' => 'status_confirmed',
    'Paid' => 'status_paid',
    'Voided' => 'status_voided',
    'Closed' => 'status_closed',
    _ => 'status_draft',
  };
  return AppStrings.get(key, lang);
}

Color _statusColor(String status, ColorScheme cs) {
  return switch (status) {
    'Draft' => Colors.grey.shade600,
    'Confirmed' => cs.primary,
    'Paid' => Colors.green.shade700,
    'Voided' => cs.error,
    'Closed' => Colors.blueGrey,
    _ => Colors.grey.shade600,
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    'Draft' => Icons.edit_note_outlined,
    'Confirmed' => Icons.check_circle_outline,
    'Paid' => Icons.paid_outlined,
    'Voided' => Icons.block_outlined,
    'Closed' => Icons.lock_outline,
    _ => Icons.edit_note_outlined,
  };
}

String _methodLabel(String method, String lang) =>
    AppStrings.methodLabel(method, lang);

// ── Item entry data class (not a widget) ──────────────────────────────────────

class _ItemEntry {
  Product? product;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();

  double get qty =>
      double.tryParse(qtyCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  double get unitPrice =>
      double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  double get subtotal => qty * unitPrice;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── InvoicesScreen ────────────────────────────────────────────────────────────

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _all = [];
  List<Invoice> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  bool _loading = true;
  bool _animate = true;

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
    final list = await DatabaseHelper.instance.getAllInvoices();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
      _animate = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    _filtered = _all.where((inv) {
      final matchStatus = _statusFilter == 'All' || inv.status == _statusFilter;
      final matchSearch =
          q.isEmpty ||
          inv.invoiceNumber.toLowerCase().contains(q) ||
          (inv.customerName?.toLowerCase().contains(q) ?? false);
      return matchStatus && matchSearch;
    }).toList();
  }

  Future<void> _openCreate(AppUser? currentUser, String lang) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _CreateInvoiceScreen(lang: lang, currentUser: currentUser),
      ),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _openDetail(Invoice invoice, String lang) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InvoiceDetailScreen(invoice: invoice, lang: lang),
      ),
    );
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s('invoices_title'))),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: s('search_invoices'),
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
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          // ── Status filter chips ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final f in ['All', 'Draft', 'Confirmed', 'Paid', 'Voided'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(
                        f == 'All'
                            ? (lang == 'ar' ? 'الكل' : 'All')
                            : _statusLabel(f, lang),
                      ),
                      selected: _statusFilter == f,
                      onSelected: (_) => setState(() {
                        _statusFilter = f;
                        _applyFilter();
                      }),
                      selectedColor: f == 'All'
                          ? cs.primaryContainer
                          : _statusColor(f, cs).withValues(alpha: 0.18),
                      checkmarkColor: f == 'All'
                          ? cs.primary
                          : _statusColor(f, cs),
                    ),
                  ),
              ],
            ),
          ),
          // ── List ──
          Expanded(
            child: _loading
                ? const SkeletonList(count: 6)
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: s('no_invoices'),
                    actionLabel: s('create_invoice'),
                    actionIcon: Icons.add,
                    onAction: () => _openCreate(state.currentUser, lang),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final card = _InvoiceCard(
                          invoice: _filtered[i],
                          lang: lang,
                          onTap: () => _openDetail(_filtered[i], lang),
                        );
                        if (!_animate) return card;
                        return card
                            .animate(delay: (40 * math.min(i, 12)).ms)
                            .fadeIn(duration: 280.ms)
                            .slideY(
                              begin: 0.18,
                              end: 0,
                              duration: 280.ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(state.currentUser, lang),
        icon: const Icon(Icons.add),
        label: Text(s('create_invoice')),
      ),
    );
  }
}

// ── Invoice card ──────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final String lang;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.invoice,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(invoice.status, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.customerName ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(status: invoice.status, lang: lang),
                        if (invoice.isOverdue) _OverdueChip(lang: lang),
                        Text(
                          Fmt.date(invoice.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Fmt.currency(invoice.grandTotal, invoice.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overdue chip (credit / بالآجل past due) ─────────────────────────────────────

class _OverdueChip extends StatelessWidget {
  final String lang;

  const _OverdueChip({required this.lang});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            AppStrings.get('status_overdue', lang),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final String lang;

  const _StatusChip({required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(status, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status, lang),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create invoice screen ─────────────────────────────────────────────────────

class _CreateInvoiceScreen extends StatefulWidget {
  final String lang;
  final AppUser? currentUser;

  const _CreateInvoiceScreen({required this.lang, this.currentUser});

  @override
  State<_CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<_CreateInvoiceScreen> {
  List<Customer> _customers = [];
  List<Product> _products = [];
  Customer? _selectedCustomer;
  final List<_ItemEntry> _rows = [];
  final _notesCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  String _currency = 'SDG';
  String? _dueDate;
  bool _vatEnabled = true;
  double _vatRate = AppConstants.defaultVatRate;
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  String _invoiceNumber = '';

  @override
  void initState() {
    super.initState();
    _rows.add(_ItemEntry());
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _dueDateCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate != null
        ? DateTime.tryParse(_dueDate!) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked.toIso8601String().split('T')[0];
        _dueDateCtrl.text = Fmt.date(_dueDate);
      });
    }
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final customers = await db.getActiveCustomers();
    final products = await db.getActiveProducts();
    final vatStr = await db.getSetting(AppConstants.vatEnabledKey);
    final vatRateStr = await db.getSetting(AppConstants.vatRateKey);
    final invNum = await db.nextInvoiceNumber();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _products = products;
      _vatEnabled = vatStr != '0';
      _vatRate =
          double.tryParse(vatRateStr ?? '') ?? AppConstants.defaultVatRate;
      _invoiceNumber = invNum;
      _loading = false;
    });
  }

  double get _subtotal => _rows.fold(0, (sum, r) => sum + r.subtotal);
  double get _tax => _vatEnabled ? _subtotal * _vatRate : 0;
  double get _grandTotal => _subtotal + _tax;

  bool get _hasValidRows => _rows.any((r) => r.qty > 0 && r.unitPrice > 0);

  Future<void> _save(String status) async {
    String s(String k) => AppStrings.get(k, widget.lang);

    if (_selectedCustomer == null) {
      setState(() => _error = s('no_customer_selected'));
      return;
    }
    if (!_hasValidRows) {
      setState(() => _error = s('no_items_error'));
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });

    final db = DatabaseHelper.instance;
    final now = Fmt.now();
    final userId = widget.currentUser?.id ?? 1;

    final invoiceMap = {
      'invoice_number': _invoiceNumber,
      'customer_id': _selectedCustomer!.id!,
      'created_by': userId,
      'total_amount': _subtotal,
      'tax_amount': _tax,
      'tax_rate': _vatEnabled ? _vatRate : 0,
      'currency': _currency,
      'due_date': _dueDate,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'status': status,
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    };

    final itemMaps = _rows
        .where((r) => r.qty > 0 && r.unitPrice > 0)
        .map(
          (r) => {
            'product_id': r.product?.id,
            'description': r.product?.name ?? '',
            'quantity': r.qty,
            'unit_price': r.unitPrice,
            'subtotal': r.subtotal,
            'created_at': now,
          },
        )
        .toList();

    try {
      await db.insertInvoiceWithItemsAndBalance(
        invoiceMap,
        itemMaps,
        status == 'Confirmed' ? _selectedCustomer!.id! : null,
        _grandTotal,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get(
              status == 'Confirmed' ? 'invoice_confirmed' : 'invoice_saved',
              widget.lang,
            ),
          ),
        ),
      );
    } catch (e, st) {
      logError('save invoice', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = s('operation_failed');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s('operation_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, widget.lang);
    final cs = Theme.of(context).colorScheme;

    Widget currencyField() => DropdownButtonFormField<String>(
      initialValue: _currency,
      decoration: InputDecoration(
        labelText: s('invoice_currency'),
        prefixIcon: const Icon(Icons.payments_outlined),
        border: const OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'SDG', child: Text('SDG')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
      ],
      onChanged: (v) => setState(() => _currency = v ?? 'SDG'),
    );

    Widget dueDateField() => TextField(
      controller: _dueDateCtrl,
      readOnly: true,
      onTap: _pickDueDate,
      decoration: InputDecoration(
        labelText: s('credit_due_date'),
        hintText: s('no_due_date'),
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: _dueDate == null
            ? null
            : IconButton(
                tooltip: s('clear_due_date'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _dueDate = null;
                  _dueDateCtrl.clear();
                }),
              ),
        border: const OutlineInputBorder(),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(s('create_invoice'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${s('invoice_number')} $_invoiceNumber',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<Customer>(
                  initialValue: _selectedCustomer,
                  hint: Text(s('select_customer')),
                  decoration: InputDecoration(
                    labelText: s('select_customer'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                  items: _customers
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCustomer = v),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          currencyField(),
                          const SizedBox(height: 14),
                          dueDateField(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 150, child: currencyField()),
                        const SizedBox(width: 12),
                        Expanded(child: dueDateField()),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s('items'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s('add_item')),
                      onPressed: () => setState(() => _rows.add(_ItemEntry())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _rows.length; i++) ...[
                  _buildItemRow(context, i, cs, s),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant, width: 0.8),
                    boxShadow: AppTokens.shadowSm,
                  ),
                  child: Column(
                    children: [
                      _TotalRow(
                        label: s('subtotal'),
                        value: Fmt.currency(_subtotal, _currency),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Switch(
                                  value: _vatEnabled,
                                  onChanged: (v) =>
                                      setState(() => _vatEnabled = v),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${s('tax_vat')} (${(_vatRate * 100).toStringAsFixed(_vatRate * 100 % 1 == 0 ? 0 : 2)}%)',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Fmt.currency(_tax, _currency),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _TotalRow(
                        label: s('total'),
                        value: Fmt.currency(_grandTotal, _currency),
                        bold: true,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: s('invoice_notes'),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_error, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                if (_saving)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  FilledButton(
                    onPressed: () => _save('Confirmed'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(s('confirm_invoice')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _save('Draft'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(s('save_draft')),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    int i,
    ColorScheme cs,
    String Function(String) s,
  ) {
    final entry = _rows[i];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${i + 1}.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_rows.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    _rows[i].dispose();
                    _rows.removeAt(i);
                  }),
                  icon: Icon(Icons.close, size: 20, color: cs.error),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Product>(
            initialValue: entry.product,
            hint: Text(
              s('select_product'),
              style: const TextStyle(fontSize: 13),
            ),
            isDense: true,
            decoration: InputDecoration(
              labelText: s('select_product'),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _products
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${p.name}  —  ${Fmt.currency(p.price)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (p) => setState(() {
              entry.product = p;
              if (p != null) {
                entry.priceCtrl.text = p.price.toStringAsFixed(2);
              }
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: entry.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s('quantity'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: entry.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s('unit_price'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s('subtotal'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        Fmt.currency(entry.subtotal, _currency),
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Invoice detail screen ─────────────────────────────────────────────────────

class _InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  final String lang;

  const _InvoiceDetailScreen({required this.invoice, required this.lang});

  @override
  State<_InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<_InvoiceDetailScreen> {
  late Invoice _invoice;
  List<InvoiceItem> _items = [];
  List<Payment> _payments = [];
  double _totalPaid = 0;
  Customer? _customer;
  bool _loading = true;
  bool _busy = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final inv = await db.getInvoiceById(_invoice.id!);
    final items = await db.getItemsForInvoice(_invoice.id!);
    final payments = await db.getPaymentsForInvoice(_invoice.id!);
    final paid = await db.getTotalPaidForInvoice(_invoice.id!);
    final customer = await db.getCustomerById(_invoice.customerId);
    if (!mounted) return;
    setState(() {
      _invoice = inv ?? _invoice;
      _items = items;
      _payments = payments;
      _totalPaid = paid;
      _customer = customer;
      _loading = false;
    });
  }

  double get _remaining => math.max(0.0, _invoice.grandTotal - _totalPaid);

  Future<void> _confirmInvoice() async {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);
    setState(() => _busy = true);

    try {
      await DatabaseHelper.instance.confirmInvoiceWithBalance(
        _invoice.id!,
        _invoice.customerId,
        _invoice.grandTotal,
        actorUserId: context.read<AppState>().currentUser?.id,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('invoice_confirmed'))));
      }
    } catch (e, st) {
      logError('confirm invoice', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('operation_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _voidInvoice(bool isAdmin) async {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    if (!isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s('admin_only_action'))));
      return;
    }
    if (_payments.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s('cannot_void_with_payments'))));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s('void_invoice')),
        content: Text(s('void_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('confirm')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.voidInvoiceWithBalance(
        _invoice.id!,
        _invoice.customerId,
        _invoice.grandTotal,
        _invoice.status == 'Confirmed',
        actorUserId: context.read<AppState>().currentUser?.id,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('invoice_voided'))));
      }
    } catch (e, st) {
      logError('void invoice', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('operation_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment() async {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);

    if (_remaining <= 0) return;

    final payment = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentForm(
        lang: lang,
        invoiceId: _invoice.id!,
        remaining: _remaining,
        currency: _invoice.currency,
      ),
    );

    if (!mounted || payment == null) return;

    try {
      await DatabaseHelper.instance.insertPaymentAndSettle(
        payment,
        _invoice.customerId,
        _invoice.id!,
        _invoice.grandTotal,
        actorUserId: context.read<AppState>().currentUser?.id,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('payment_saved'))));
      }
    } catch (e, st) {
      logError('record payment', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('operation_failed'))));
      }
    }
  }

  Future<void> _reversePayment(Payment payment) async {
    final state = context.read<AppState>();
    final ar = state.isArabic;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'عكس الدفعة' : 'Reverse Payment'),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: ar ? 'سبب العكس (مطلوب)' : 'Reversal reason (required)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'تأكيد العكس' : 'Confirm Reversal'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || text.length < 3 || payment.id == null) return;
    try {
      await DatabaseHelper.instance.reversePayment(
        paymentId: payment.id!,
        actorUserId: state.currentUser!.id!,
        reason: text,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ar ? 'تم عكس الدفعة' : 'Payment reversed')),
        );
      }
    } catch (e, st) {
      logError('reverse payment', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('operation_failed', state.language)),
          ),
        );
      }
    }
  }

  Future<Uint8List?> _buildPdfBytes() async {
    final db = DatabaseHelper.instance;
    final values = await Future.wait([
      db.getSetting(AppConstants.storeNameKey),
      db.getSetting(AppConstants.storeAddressKey),
      db.getSetting(AppConstants.storePhoneKey),
      db.getSetting(AppConstants.taxIdKey),
      db.getSetting(AppConstants.commercialRegistrationKey),
    ]);
    final rawName = values[0];
    final storeName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'Billing Management System';
    return PdfService.generate(
      invoice: _invoice,
      items: _items,
      payments: _payments,
      totalPaid: _totalPaid,
      storeName: storeName,
      storeAddress: values[1] ?? '',
      storePhone: values[2] ?? '',
      taxId: values[3] ?? '',
      commercialRegistration: values[4] ?? '',
      customer: _customer,
      lang: widget.lang,
    );
  }

  Future<void> _notifyWhatsApp() async {
    final lang = widget.lang;
    final phone = _customer?.phone ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('no_phone_for_notify', lang))),
        );
      }
      return;
    }
    // Sudan numbers: 09xxxxxxxx → 2499xxxxxxxx (wa.me needs international form).
    final intl = SudanPhone.toInternational(phone);

    final statusLabel = _statusLabel(_invoice.status, lang);
    final amount = Fmt.currency(_invoice.grandTotal, _invoice.currency);
    final due = _invoice.dueDate?.isNotEmpty == true
        ? (lang == 'ar'
              ? ' تاريخ الاستحقاق: ${Fmt.date(_invoice.dueDate!)}.'
              : ' Due date: ${Fmt.date(_invoice.dueDate!)}.')
        : '';
    final msg = lang == 'ar'
        ? 'مرحباً ${_invoice.customerName ?? ''}، فاتورتك رقم ${_invoice.invoiceNumber} بقيمة $amount - الحالة: $statusLabel.$due شكراً لتعاملكم معنا.'
        : 'Dear ${_invoice.customerName ?? ''}, invoice ${_invoice.invoiceNumber} amount $amount - Status: $statusLabel.$due Thank you for your business.';

    final url = Uri.parse(
      'https://wa.me/$intl?text=${Uri.encodeComponent(msg)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('whatsapp_not_found', lang))),
      );
    }
  }

  Future<void> _notifySms() async {
    final lang = widget.lang;
    final phone = _customer?.phone ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('no_phone_for_notify', lang))),
        );
      }
      return;
    }
    final statusLabel = _statusLabel(_invoice.status, lang);
    final amount = Fmt.currency(_invoice.grandTotal, _invoice.currency);
    final msg = lang == 'ar'
        ? 'فاتورة ${_invoice.invoiceNumber}: $amount - $statusLabel'
        : 'Invoice ${_invoice.invoiceNumber}: $amount - $statusLabel';
    final url = Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('sms_not_available', lang))),
      );
    }
  }

  void _showQrCode() {
    final lang = widget.lang;
    final data =
        'INV:${_invoice.invoiceNumber}\nAMOUNT:${_invoice.grandTotal}\nSTATUS:${_invoice.status}\nCUSTOMER:${_invoice.customerName ?? ''}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.get('view_qr', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: data,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _invoice.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.get('scan_qr_hint', lang),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('close', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);
    setState(() => _generating = true);
    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      setState(() => _generating = false);
      if (bytes != null) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'invoice_${_invoice.invoiceNumber}.pdf',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s('pdf_error'))));
    }
  }

  Future<void> _sharePdf() async {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);
    setState(() => _generating = true);
    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      setState(() => _generating = false);
      if (bytes != null) {
        await ShareService.shareInvoicePdf(bytes, _invoice.invoiceNumber);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s('share_error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final isAdmin = context.read<AppState>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: _StatusChip(status: _invoice.status, lang: lang),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InvoiceSummaryCard(
                  invoice: _invoice,
                  totalPaid: _totalPaid,
                  remaining: _remaining,
                  lang: lang,
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _invoice.customerName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Fmt.date(_invoice.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (_invoice.dueDate?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: _invoice.isOverdue
                                  ? cs.error
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${s('due_date')}: ${Fmt.date(_invoice.dueDate)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: _invoice.isOverdue
                                          ? cs.error
                                          : null,
                                      fontWeight: _invoice.isOverdue
                                          ? FontWeight.w700
                                          : null,
                                    ),
                              ),
                            ),
                            if (_invoice.isOverdue) ...[
                              const SizedBox(width: 6),
                              _OverdueChip(lang: lang),
                            ],
                          ],
                        ),
                      ],
                      if (_invoice.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _invoice.notes!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: s('items'),
                  child: Column(
                    children: [
                      for (final item in _items)
                        _ItemDetailRow(item: item, currency: _invoice.currency),
                      const Divider(),
                      _TotalRow(
                        label: s('subtotal'),
                        value: Fmt.currency(
                          _invoice.totalAmount,
                          _invoice.currency,
                        ),
                      ),
                      if (_invoice.taxAmount > 0)
                        _TotalRow(
                          label: s('tax_vat'),
                          value: Fmt.currency(
                            _invoice.taxAmount,
                            _invoice.currency,
                          ),
                        ),
                      _TotalRow(
                        label: s('total'),
                        value: Fmt.currency(
                          _invoice.grandTotal,
                          _invoice.currency,
                        ),
                        bold: true,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: s('payment_history'),
                  child: Column(
                    children: [
                      if (_payments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            s('no_payments'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        )
                      else
                        for (final p in _payments)
                          _PaymentHistoryRow(
                            payment: p,
                            lang: lang,
                            currency: _invoice.currency,
                            onReverse: isAdmin
                                ? () => _reversePayment(p)
                                : null,
                          ),
                      if (_payments.isNotEmpty) ...[
                        const Divider(),
                        _TotalRow(
                          label: s('total_paid'),
                          value: Fmt.currency(_totalPaid, _invoice.currency),
                        ),
                        _TotalRow(
                          label: s('remaining_balance'),
                          value: Fmt.currency(_remaining, _invoice.currency),
                          color: _remaining > 0.01
                              ? cs.error
                              : Colors.green.shade700,
                          bold: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (_invoice.status == 'Draft') ...[
                    FilledButton(
                      onPressed: _confirmInvoice,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(s('confirm_invoice')),
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin)
                      OutlinedButton(
                        onPressed: () => _voidInvoice(isAdmin),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                        child: Text(s('void_invoice')),
                      ),
                  ],
                  if (_invoice.status == 'Confirmed') ...[
                    FilledButton(
                      onPressed: _recordPayment,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(s('record_payment')),
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin && _payments.isEmpty)
                      OutlinedButton(
                        onPressed: () => _voidInvoice(isAdmin),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                        child: Text(s('void_invoice')),
                      ),
                  ],
                ],
                if ([
                  'Draft',
                  'Confirmed',
                  'Paid',
                ].contains(_invoice.status)) ...[
                  const SizedBox(height: 10),
                  if (_generating)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _generatePdf,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(s('generate_pdf')),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _sharePdf,
                            icon: const Icon(Icons.share_outlined),
                            label: Text(s('share_invoice')),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                // WhatsApp / SMS / QR row
                if (!['Voided', 'Closed'].contains(_invoice.status)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _notifyWhatsApp,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text(
                            AppStrings.get('notify_whatsapp', lang),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _notifySms,
                          icon: const Icon(Icons.sms_outlined, size: 18),
                          label: Text(
                            AppStrings.get('notify_sms', lang),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _showQrCode,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Icon(Icons.qr_code_2_outlined),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

// ── Payment form (bottom sheet) ───────────────────────────────────────────────

class _PaymentForm extends StatefulWidget {
  final String lang;
  final int invoiceId;
  final double remaining;
  final String currency;

  const _PaymentForm({
    required this.lang,
    required this.invoiceId,
    required this.remaining,
    required this.currency,
  });

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'Cash';
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String s(String k) => AppStrings.get(k, widget.lang);

    final amount = double.tryParse(
      _amountCtrl.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = s('invalid_number'));
      return;
    }
    if (amount > widget.remaining + 0.01) {
      setState(() => _error = s('amount_exceeds_remaining'));
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    final now = Fmt.now();
    final payment = Payment(
      invoiceId: widget.invoiceId,
      amountPaid: amount,
      paymentDate: now,
      method: _method,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: now,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, payment);
  }

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, widget.lang);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
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
              s('record_payment'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s('remaining_balance'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    Fmt.currency(widget.remaining, widget.currency),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: () => setState(
                  () => _amountCtrl.text = widget.remaining.toStringAsFixed(2),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.lang == 'ar'
                        ? 'دفع الكامل: ${Fmt.currency(widget.remaining, widget.currency)}'
                        : 'Pay in full: ${Fmt.currency(widget.remaining, widget.currency)}',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: s('amount_paid'),
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(
                labelText: s('payment_method'),
                prefixIcon: const Icon(Icons.credit_card_outlined),
                border: const OutlineInputBorder(),
              ),
              items: AppConstants.paymentMethods
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(_methodLabel(m, widget.lang)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? 'Cash'),
            ),
            const SizedBox(height: 14),
            // For Bankak/Bede/Cashi/bank transfers this doubles as the
            // transaction-reference field — how shops reconcile transfers.
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _method == 'Cash'
                    ? s('payment_notes')
                    : s('payment_reference'),
                prefixIcon: Icon(
                  _method == 'Cash' ? Icons.notes_outlined : Icons.tag_outlined,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
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
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
        boxShadow: AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  final Invoice invoice;
  final double totalPaid;
  final double remaining;
  final String lang;

  const _InvoiceSummaryCard({
    required this.invoice,
    required this.totalPaid,
    required this.remaining,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final grandTotal = invoice.grandTotal;
    final progress = grandTotal > 0
        ? (totalPaid / grandTotal).clamp(0.0, 1.0)
        : 0.0;
    final isPaid = remaining <= 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invoice.customerName?.isNotEmpty == true) ...[
            Text(
              invoice.customerName!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            Fmt.currency(grandTotal, invoice.currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: isPaid ? Colors.greenAccent.shade400 : Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s('total_paid'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      Fmt.currency(totalPaid, invoice.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isPaid ? s('status_paid') : s('remaining_balance'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      isPaid ? '✓' : Fmt.currency(remaining, invoice.currency),
                      style: TextStyle(
                        color: isPaid
                            ? Colors.greenAccent.shade400
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ItemDetailRow extends StatelessWidget {
  final InvoiceItem item;
  final String currency;

  const _ItemDetailRow({required this.item, this.currency = 'SDG'});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qtyStr = item.quantity == item.quantity.truncateToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(item.description, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(
            '$qtyStr × ${Fmt.currency(item.unitPrice, currency)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            Fmt.currency(item.subtotal, currency),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  final Payment payment;
  final String lang;
  final String currency;
  final VoidCallback? onReverse;

  const _PaymentHistoryRow({
    required this.payment,
    required this.lang,
    this.currency = 'SDG',
    this.onReverse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _methodLabel(payment.method, lang),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  Fmt.date(payment.paymentDate),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (payment.notes?.isNotEmpty == true)
                  Text(
                    payment.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            Fmt.currency(payment.amountPaid, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
              fontSize: 13,
            ),
          ),
          if (onReverse != null)
            IconButton(
              tooltip: lang == 'ar' ? 'عكس الدفعة' : 'Reverse payment',
              onPressed: onReverse,
              icon: const Icon(Icons.undo, size: 18),
              color: cs.error,
            ),
        ],
      ),
    );
  }
}
