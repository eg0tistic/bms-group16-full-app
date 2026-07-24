import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../models/utility_payment.dart';
import '../services/pdf_service.dart';
import '../utils/app_strings.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';

enum _UtilityType { electricity, water, telecom }

extension on _UtilityType {
  String get canonical => switch (this) {
    _UtilityType.electricity => 'Electricity',
    _UtilityType.water => 'Water',
    _UtilityType.telecom => 'Telecom',
  };
}

String _typeKey(String canonical) => switch (canonical) {
  'Electricity' => 'utility_electricity',
  'Water' => 'utility_water',
  _ => 'utility_telecom',
};

Color _typeColor(String canonical, ColorScheme cs) => switch (canonical) {
  'Electricity' => const Color(0xFFB45309),
  'Water' => const Color(0xFF1D4ED8),
  _ => cs.secondary,
};

IconData _typeIcon(String canonical) => switch (canonical) {
  'Electricity' => Icons.bolt_outlined,
  'Water' => Icons.water_drop_outlined,
  _ => Icons.cell_tower_outlined,
};

/// Records utility bills (electricity, water, telecom) the shop paid to the
/// provider on a customer's behalf. No Sudanese utility exposes a public API
/// to check or pay bills live, so this is a real local ledger for the manual
/// workflow shops already use — not a simulated provider connection.
class UtilityBillsScreen extends StatefulWidget {
  const UtilityBillsScreen({super.key});

  @override
  State<UtilityBillsScreen> createState() => _UtilityBillsScreenState();
}

class _UtilityBillsScreenState extends State<UtilityBillsScreen> {
  final _formKey = GlobalKey<FormState>();
  _UtilityType _type = _UtilityType.electricity;
  final _providerCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _payerNameCtrl = TextEditingController();
  final _payerPhoneCtrl = TextEditingController();
  final _billAmountCtrl = TextEditingController();
  final _serviceFeeCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'Cash';
  bool _saving = false;
  bool _loadingHistory = true;
  List<UtilityPayment> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _accountCtrl.dispose();
    _payerNameCtrl.dispose();
    _payerPhoneCtrl.dispose();
    _billAmountCtrl.dispose();
    _serviceFeeCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await DatabaseHelper.instance.getUtilityPayments();
      if (mounted) {
        setState(() {
          _history = rows;
          _loadingHistory = false;
        });
      }
    } catch (e, st) {
      logError('load utility payments', e, st);
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _save() async {
    final lang = context.read<AppState>().language;
    String s(String k) => AppStrings.get(k, lang);
    if (!_formKey.currentState!.validate()) return;

    final billAmount =
        double.tryParse(_billAmountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final serviceFee =
        double.tryParse(_serviceFeeCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final userId = context.read<AppState>().currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final rawPhone = _payerPhoneCtrl.text.trim();
      final payerPhone = rawPhone.isEmpty
          ? null
          : (SudanPhone.normalize(rawPhone) ?? rawPhone);
      await DatabaseHelper.instance.insertUtilityPayment(
        UtilityPayment(
          utilityType: _type.canonical,
          provider: _providerCtrl.text.trim(),
          accountNumber: _accountCtrl.text.trim(),
          payerName: _payerNameCtrl.text.trim().isEmpty
              ? null
              : _payerNameCtrl.text.trim(),
          payerPhone: payerPhone,
          billAmount: billAmount,
          serviceFee: serviceFee,
          paymentMethod: _method,
          reference: _referenceCtrl.text.trim().isEmpty
              ? null
              : _referenceCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdBy: userId,
          createdAt: Fmt.now(),
        ),
      );

      _providerCtrl.clear();
      _accountCtrl.clear();
      _payerNameCtrl.clear();
      _payerPhoneCtrl.clear();
      _billAmountCtrl.clear();
      _serviceFeeCtrl.clear();
      _referenceCtrl.clear();
      _notesCtrl.clear();
      // Clearing the controllers counts as "user interaction", so the
      // emptied required fields would immediately show validation errors.
      _formKey.currentState?.reset();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('payment_saved'))));
      }
    } catch (e, st) {
      logError('save utility payment', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s('operation_failed'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    final billAmount = double.tryParse(
      _billAmountCtrl.text.trim().replaceAll(',', '.'),
    );
    final serviceFee =
        double.tryParse(_serviceFeeCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(s('utility_bills_title'))),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Honest explainer: this is a manual ledger, not a live provider link.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.secondary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: cs.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s('utility_explainer'),
                    style: TextStyle(
                      color: cs.secondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            s('utility_record_payment'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant, width: 0.8),
                boxShadow: AppTokens.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // On narrow screens the icon + label pair forces the Arabic
                  // labels to wrap mid-word, so icons are dropped below 380px.
                  Builder(
                    builder: (context) {
                      final compact = MediaQuery.of(context).size.width < 380;
                      Text segLabel(String key) => Text(
                        s(key),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      );
                      return SegmentedButton<_UtilityType>(
                        showSelectedIcon: !compact,
                        selected: {_type},
                        onSelectionChanged: (v) =>
                            setState(() => _type = v.first),
                        segments: [
                          ButtonSegment(
                            value: _UtilityType.electricity,
                            label: segLabel('utility_electricity'),
                            icon: compact
                                ? null
                                : const Icon(Icons.bolt_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: _UtilityType.water,
                            label: segLabel('utility_water'),
                            icon: compact
                                ? null
                                : const Icon(
                                    Icons.water_drop_outlined,
                                    size: 18,
                                  ),
                          ),
                          ButtonSegment(
                            value: _UtilityType.telecom,
                            label: segLabel('utility_telecom'),
                            icon: compact
                                ? null
                                : const Icon(
                                    Icons.cell_tower_outlined,
                                    size: 18,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _providerCtrl,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? s('required_field')
                        : null,
                    decoration: InputDecoration(
                      labelText: s('service_provider'),
                      prefixIcon: const Icon(Icons.hub_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _accountCtrl,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? s('required_field')
                        : null,
                    decoration: InputDecoration(
                      labelText: s('account_number'),
                      prefixIcon: const Icon(Icons.tag_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _payerNameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: s('utility_payer_name'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _payerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => SudanPhone.isValidOrEmpty(v ?? '')
                        ? null
                        : s('invalid_phone'),
                    decoration: InputDecoration(
                      labelText: s('utility_payer_phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _billAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'),
                            );
                            return (n == null || n <= 0)
                                ? s('required_field')
                                : null;
                          },
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: s('utility_bill_amount'),
                            prefixIcon: const Icon(Icons.receipt_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _serviceFeeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: s('utility_service_fee'),
                            prefixIcon: const Icon(Icons.add_card_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (billAmount != null && billAmount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s('utility_total_collected'),
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            Fmt.currency(billAmount + serviceFee),
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: InputDecoration(
                      labelText: s('payment_method'),
                      prefixIcon: const Icon(Icons.credit_card_outlined),
                    ),
                    items: AppConstants.paymentMethods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(AppStrings.methodLabel(m, lang)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _method = v ?? 'Cash'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _referenceCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: s('payment_reference'),
                      prefixIcon: const Icon(
                        Icons.confirmation_number_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: s('payment_notes'),
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(s('save')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),
          Text(
            s('utility_history'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: s('utility_no_history'),
              ),
            )
          else
            for (final p in _history)
              _UtilityPaymentTile(payment: p, lang: lang),
        ],
      ),
    );
  }
}

// ── History tile + detail sheet ───────────────────────────────────────────────

class _UtilityPaymentTile extends StatelessWidget {
  final UtilityPayment payment;
  final String lang;

  const _UtilityPaymentTile({required this.payment, required this.lang});

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final color = _typeColor(payment.utilityType, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(context, s),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _typeIcon(payment.utilityType),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      payment.payerName?.isNotEmpty == true
                          ? '${payment.payerName} · ${payment.accountNumber}'
                          : payment.accountNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.currency(payment.totalCollected),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Fmt.date(payment.createdAt),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String Function(String) s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UtilityPaymentDetailSheet(payment: payment, lang: lang),
    );
  }
}

class _UtilityPaymentDetailSheet extends StatefulWidget {
  final UtilityPayment payment;
  final String lang;

  const _UtilityPaymentDetailSheet({required this.payment, required this.lang});

  @override
  State<_UtilityPaymentDetailSheet> createState() =>
      _UtilityPaymentDetailSheetState();
}

class _UtilityPaymentDetailSheetState
    extends State<_UtilityPaymentDetailSheet> {
  bool _generating = false;

  Future<void> _printReceipt() async {
    setState(() => _generating = true);
    try {
      final storeName = await DatabaseHelper.instance.getSetting(
        AppConstants.storeNameKey,
      );
      final bytes = await PdfService.generateUtilityReceipt(
        payment: widget.payment,
        storeName: (storeName?.isNotEmpty == true)
            ? storeName!
            : AppConstants.defaultStoreName,
        lang: widget.lang,
      );
      if (!mounted) return;
      setState(() => _generating = false);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'utility_receipt_${widget.payment.id}.pdf',
      );
    } catch (e, st) {
      logError('generate utility receipt', e, st);
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('pdf_error', widget.lang))),
      );
    }
  }

  Future<void> _notifyWhatsApp() async {
    final lang = widget.lang;
    final phone = widget.payment.payerPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('no_phone_for_notify', lang))),
      );
      return;
    }
    final intl = SudanPhone.toInternational(phone);
    final amount = Fmt.currency(widget.payment.totalCollected);
    final typeLabel = AppStrings.get(
      _typeKey(widget.payment.utilityType),
      lang,
    );
    final msg = lang == 'ar'
        ? 'مرحباً${widget.payment.payerName != null ? ' ${widget.payment.payerName}' : ''}، تم دفع فاتورة $typeLabel (${widget.payment.provider}) بمبلغ $amount. شكراً لتعاملكم معنا.'
        : 'Dear${widget.payment.payerName != null ? ' ${widget.payment.payerName}' : ''}, your $typeLabel bill (${widget.payment.provider}) has been paid, total $amount. Thank you.';
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

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final p = widget.payment;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final color = _typeColor(p.utilityType, cs);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(p.utilityType), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.provider,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        s(_typeKey(p.utilityType)),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(label: s('account_number'), value: p.accountNumber),
            if (p.payerName?.isNotEmpty == true)
              _DetailRow(label: s('utility_payer_name'), value: p.payerName!),
            if (p.payerPhone?.isNotEmpty == true)
              _DetailRow(label: s('utility_payer_phone'), value: p.payerPhone!),
            _DetailRow(
              label: s('utility_bill_amount'),
              value: Fmt.currency(p.billAmount),
            ),
            if (p.serviceFee > 0)
              _DetailRow(
                label: s('utility_service_fee'),
                value: Fmt.currency(p.serviceFee),
              ),
            _DetailRow(
              label: s('utility_total_collected'),
              value: Fmt.currency(p.totalCollected),
              bold: true,
            ),
            _DetailRow(
              label: s('payment_method'),
              value: AppStrings.methodLabel(p.paymentMethod, lang),
            ),
            if (p.reference?.isNotEmpty == true)
              _DetailRow(label: s('payment_reference'), value: p.reference!),
            if (p.notes?.isNotEmpty == true)
              _DetailRow(label: s('payment_notes'), value: p.notes!),
            _DetailRow(
              label: s('pdf_date'),
              value: Fmt.dateTime(p.createdAt),
              last: true,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _generating ? null : _printReceipt,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text(s('generate_pdf')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (p.payerPhone?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _notifyWhatsApp,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: Text(s('notify_whatsapp')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool last;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
