import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../models/product.dart';
import '../utils/app_strings.dart';
import '../utils/logger.dart';
import '../widgets/empty_state.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeletons.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _all = [];
  List<Product> _filtered = [];
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
    final list = await DatabaseHelper.instance.getActiveProducts();
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
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q),
              )
              .toList();
  }

  Future<void> _showForm({Product? product}) async {
    final lang = context.read<AppState>().language;
    final result = await showModalBottomSheet<Product?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductForm(lang: lang, existing: product),
    );

    if (!mounted || result == null) return;

    final db = DatabaseHelper.instance;
    try {
      if (product == null) {
        await db.insertProduct(result);
      } else {
        await db.updateProduct(result);
      }
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('product_saved', lang))),
        );
      }
    } catch (e, st) {
      logError('save product', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('operation_failed', lang))),
        );
      }
    }
  }

  Future<void> _deactivate(Product product) async {
    final lang = context.read<AppState>().language;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.get('deactivate_product', lang)),
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
      await DatabaseHelper.instance.deactivateProduct(product.id!);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('product_deactivated', lang))),
        );
      }
    } catch (e, st) {
      logError('deactivate product', e, st);
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
      appBar: AppBar(title: Text(s('products_title'))),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: s('search_products'),
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
                    icon: Icons.inventory_2_outlined,
                    title: s('no_products'),
                    actionLabel: isAdmin ? s('add_product') : null,
                    actionIcon: Icons.add_business,
                    onAction: isAdmin ? () => _showForm() : null,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: _filtered[i],
                        lang: lang,
                        isAdmin: isAdmin,
                        onEdit: () => _showForm(product: _filtered[i]),
                        onDeactivate: () => _deactivate(_filtered[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: Text(s('add_product')),
            )
          : null,
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final String lang;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _ProductCard({
    required this.product,
    required this.lang,
    required this.isAdmin,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;
    final meta = [
      if (product.category.isNotEmpty) product.category,
      if (product.unit.isNotEmpty) product.unit,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: cs.secondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (product.category.isNotEmpty)
                            _MetaChip(text: product.category),
                          if (product.unit.isNotEmpty)
                            _MetaChip(text: product.unit),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _PriceBadge(text: Fmt.currency(product.price)),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                _CardMenu(
                  onEdit: onEdit,
                  onDeactivate: onDeactivate,
                  editLabel: s('edit'),
                  deactivateLabel: s('deactivate_product'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final String text;

  const _PriceBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
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
              Icon(Icons.remove_circle_outline, size: 18, color: cs.error),
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

class _ProductForm extends StatefulWidget {
  final String lang;
  final Product? existing;

  const _ProductForm({required this.lang, this.existing});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _unitCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _categoryCtrl = TextEditingController(
      text: widget.existing?.category ?? '',
    );
    _priceCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.price.toStringAsFixed(2)
          : '',
    );
    _unitCtrl = TextEditingController(text: widget.existing?.unit ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.parse(_priceCtrl.text.trim().replaceAll(',', '.'));
    Navigator.pop(
      context,
      Product(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        price: price,
        unit: _unitCtrl.text.trim(),
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
                isEditing ? s('edit_product_title') : s('add_product_title'),
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
                  labelText: s('product_name'),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoryCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s('product_category'),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  final price = double.tryParse(
                    (v ?? '').trim().replaceAll(',', '.'),
                  );
                  return (price == null || price <= 0)
                      ? s('invalid_number')
                      : null;
                },
                decoration: InputDecoration(
                  labelText: s('product_price'),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _unitCtrl,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: s('product_unit'),
                  prefixIcon: const Icon(Icons.straighten_outlined),
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
