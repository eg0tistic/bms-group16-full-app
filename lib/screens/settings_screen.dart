import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../services/sync_service.dart';
import '../services/backup_service.dart';
import '../utils/app_strings.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

String _localizeSync(SyncResult r, String lang) {
  String s(String k) => AppStrings.get(k, lang);
  return switch (r.code) {
    SyncResultCode.notConfigured => s('sync_not_configured'),
    SyncResultCode.noInternet => s('no_internet'),
    SyncResultCode.upToDate => s('sync_up_to_date'),
    SyncResultCode.success => '${s('sync_success')} (${r.pushedCount})',
    SyncResultCode.partial =>
      '${s('sync_partial')}: ${r.pushedCount} / ${r.pushedCount + r.failedCount}',
    SyncResultCode.failed => '${s('sync_failed')} (${r.failedCount})',
  };
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _commercialRegCtrl = TextEditingController();
  final _vatRateCtrl = TextEditingController();
  bool _editingName = false;
  bool _savingName = false;
  bool _vatEnabled = true;

  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _savingConfig = false;

  bool _syncing = false;
  String _syncMessage = '';
  bool _syncSuccess = false;
  String _lastSynced = '';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _taxIdCtrl.dispose();
    _commercialRegCtrl.dispose();
    _vatRateCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final db = DatabaseHelper.instance;
    final name = await db.getSetting(AppConstants.storeNameKey);
    final vatStr = await db.getSetting(AppConstants.vatEnabledKey);
    final address = await db.getSetting(AppConstants.storeAddressKey);
    final phone = await db.getSetting(AppConstants.storePhoneKey);
    final taxId = await db.getSetting(AppConstants.taxIdKey);
    final commercialReg = await db.getSetting(
      AppConstants.commercialRegistrationKey,
    );
    final vatRate = await db.getSetting(AppConstants.vatRateKey);
    final url = await db.getSetting(AppConstants.supabaseUrlKey);
    final key = await db.getSetting(AppConstants.supabaseAnonKey);
    final last = await db.getSetting(AppConstants.lastSyncedKey);
    final pending = await db.getPendingSyncCount();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name ?? '';
      _vatEnabled = vatStr != '0';
      _addressCtrl.text = address ?? '';
      _phoneCtrl.text = phone ?? '';
      _taxIdCtrl.text = taxId ?? '';
      _commercialRegCtrl.text = commercialReg ?? '';
      _vatRateCtrl.text =
          ((double.tryParse(vatRate ?? '') ?? AppConstants.defaultVatRate) *
                  100)
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.00$'), '');
      _urlCtrl.text = url ?? '';
      _keyCtrl.text = key ?? '';
      _lastSynced = (last != null && last.isNotEmpty) ? last : '';
      _pendingCount = pending;
    });
  }

  Future<void> _saveTaxProfile(String lang) async {
    final ratePercent = double.tryParse(
      _vatRateCtrl.text.trim().replaceAll(',', '.'),
    );
    if (ratePercent == null || ratePercent < 0 || ratePercent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'أدخل نسبة ضريبة بين 0 و100'
                : 'Enter a VAT rate between 0 and 100',
          ),
        ),
      );
      return;
    }
    setState(() => _savingConfig = true);
    try {
      final db = DatabaseHelper.instance;
      await db.setSetting(
        AppConstants.storeAddressKey,
        _addressCtrl.text.trim(),
      );
      await db.setSetting(AppConstants.storePhoneKey, _phoneCtrl.text.trim());
      await db.setSetting(AppConstants.taxIdKey, _taxIdCtrl.text.trim());
      await db.setSetting(
        AppConstants.commercialRegistrationKey,
        _commercialRegCtrl.text.trim(),
      );
      await db.setSetting(
        AppConstants.vatRateKey,
        (ratePercent / 100).toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('settings_saved', lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _changePassword(AppState state) async {
    final ar = state.isArabic;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String error = '';
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ar ? 'تغيير كلمة المرور' : 'Change Password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ar ? 'كلمة المرور الحالية' : 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ar ? 'كلمة المرور الجديدة' : 'New password',
                    helperText: ar
                        ? '8 أحرف على الأقل'
                        : 'At least 8 characters',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ar ? 'تأكيد كلمة المرور' : 'Confirm password',
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (next.text.length < 8 || next.text != confirm.text) {
                  setDialogState(
                    () => error = ar
                        ? 'تأكد من تطابق كلمة المرور وأنها 8 أحرف على الأقل'
                        : 'Passwords must match and contain at least 8 characters',
                  );
                  return;
                }
                final ok = await DatabaseHelper.instance.changePassword(
                  userId: state.currentUser!.id!,
                  currentPassword: current.text,
                  newPassword: next.text,
                );
                if (!dialogContext.mounted) return;
                if (!ok) {
                  setDialogState(
                    () => error = ar
                        ? 'كلمة المرور الحالية غير صحيحة'
                        : 'Current password is incorrect',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(ar ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'تم تغيير كلمة المرور' : 'Password changed'),
        ),
      );
    }
  }

  Future<void> _toggleVat(bool value) async {
    setState(() => _vatEnabled = value);
    await DatabaseHelper.instance.setSetting(
      AppConstants.vatEnabledKey,
      value ? '1' : '0',
    );
  }

  Future<void> _saveName() async {
    final lang = context.read<AppState>().language;
    setState(() => _savingName = true);
    try {
      await DatabaseHelper.instance.setSetting(
        AppConstants.storeNameKey,
        _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _editingName = false);
    } catch (e, st) {
      logError('save store name', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('operation_failed', lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _saveConfig(String lang) async {
    setState(() => _savingConfig = true);
    final db = DatabaseHelper.instance;
    try {
      await db.setSetting(AppConstants.supabaseUrlKey, _urlCtrl.text.trim());
      await db.setSetting(AppConstants.supabaseAnonKey, _keyCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('settings_saved', lang))),
      );
    } catch (e, st) {
      logError('save config', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('operation_failed', lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _syncNow(String lang) async {
    setState(() {
      _syncing = true;
      _syncMessage = '';
    });

    final result = await SyncService.sync();

    if (!mounted) return;
    final pending = await DatabaseHelper.instance.getPendingSyncCount();
    final last = await DatabaseHelper.instance.getSetting(
      AppConstants.lastSyncedKey,
    );

    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncSuccess = result.success;
      _syncMessage = _localizeSync(result, lang);
      _pendingCount = pending;
      _lastSynced = (last != null && last.isNotEmpty) ? last : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final isAdmin = state.isAdmin;
    final cs = Theme.of(context).colorScheme;
    String s(String k) => AppStrings.get(k, lang);

    return Scaffold(
      appBar: AppBar(title: Text(s('settings_title'))),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsSection(
            title: s('store_settings'),
            icon: Icons.storefront_outlined,
            children: [
              _StoreNameTile(
                label: s('store_name'),
                value: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '-',
                isAdmin: isAdmin,
                editing: _editingName,
                saving: _savingName,
                controller: _nameCtrl,
                onEdit: () => setState(() => _editingName = true),
                onCancel: () {
                  _loadAll();
                  setState(() => _editingName = false);
                },
                onSave: _saveName,
                saveLabel: s('save'),
                cancelLabel: s('cancel'),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.language_outlined,
                title: s('language'),
                subtitle: state.isArabic ? s('language_ar') : s('language_en'),
                value: state.isArabic,
                onChanged: (_) =>
                    state.setLanguage(state.isArabic ? 'en' : 'ar'),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.percent_outlined,
                title: s('vat_toggle'),
                subtitle: s('vat_applies_note'),
                value: _vatEnabled,
                onChanged: isAdmin ? _toggleVat : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isAdmin) ...[
            _SettingsSection(
              title: lang == 'ar' ? 'سلامة البيانات' : 'Data Safety',
              icon: Icons.security_outlined,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    lang == 'ar'
                        ? 'صدّر نسخة احتياطية دورياً. لا تتضمن النسخة مفتاح Supabase أو كلمات المرور.'
                        : 'Export a backup regularly. Supabase keys and passwords are excluded.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await BackupService.exportBusinessData();
                          } catch (e, st) {
                            logError('export backup', e, st);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s('operation_failed'))),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(
                          lang == 'ar'
                              ? 'تصدير نسخة احتياطية'
                              : 'Export Backup',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await DatabaseHelper.instance
                              .rebuildAllCustomerBalances(
                                actorUserId: state.currentUser?.id,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  lang == 'ar'
                                      ? 'تم التحقق من أرصدة العملاء'
                                      : 'Customer balances verified',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.calculate_outlined),
                        label: Text(
                          lang == 'ar'
                              ? 'فحص وإعادة حساب الأرصدة'
                              : 'Verify & Rebuild Balances',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _SettingsSection(
            title: lang == 'ar'
                ? 'الملف التجاري والضريبي'
                : 'Business & Tax Profile',
            icon: Icons.badge_outlined,
            children: [
              for (final field in [
                (
                  _addressCtrl,
                  lang == 'ar' ? 'عنوان المتجر' : 'Store address',
                  Icons.location_on_outlined,
                ),
                (
                  _phoneCtrl,
                  lang == 'ar' ? 'هاتف المتجر' : 'Store phone',
                  Icons.phone_outlined,
                ),
                (
                  _taxIdCtrl,
                  lang == 'ar' ? 'الرقم الضريبي' : 'Tax identification number',
                  Icons.numbers_outlined,
                ),
                (
                  _commercialRegCtrl,
                  lang == 'ar' ? 'السجل التجاري' : 'Commercial registration',
                  Icons.assignment_outlined,
                ),
                (
                  _vatRateCtrl,
                  lang == 'ar' ? 'نسبة الضريبة %' : 'VAT rate %',
                  Icons.percent_outlined,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: field.$1,
                    enabled: isAdmin,
                    keyboardType: identical(field.$1, _vatRateCtrl)
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: field.$2,
                      prefixIcon: Icon(field.$3),
                    ),
                  ),
                ),
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _savingConfig
                        ? null
                        : () => _saveTaxProfile(lang),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(s('save')),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: s('cloud_sync'),
            icon: Icons.cloud_sync_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  s('offline_mode_note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _urlCtrl,
                  enabled: isAdmin,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: s('supabase_url'),
                    hintText: 'https://xxxx.supabase.co',
                    prefixIcon: const Icon(Icons.link_outlined),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _keyCtrl,
                  enabled: isAdmin,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: s('supabase_key'),
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: isAdmin
                        ? IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          )
                        : null,
                  ),
                ),
              ),
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _savingConfig
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton.icon(
                          onPressed: () => _saveConfig(lang),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: Text(s('save')),
                        ),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SyncFacts(
                  pendingLabel: s('pending_sync'),
                  pendingCount: _pendingCount,
                  lastSyncedLabel: s('last_synced'),
                  lastSynced: _lastSynced.isNotEmpty
                      ? _lastSynced
                      : s('not_synced_yet'),
                ),
              ),
              if (_syncMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SyncMessage(
                    message: _syncMessage,
                    success: _syncSuccess,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: _syncing
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton.icon(
                        onPressed: isAdmin ? () => _syncNow(lang) : null,
                        icon: const Icon(Icons.sync_outlined, size: 18),
                        label: Text(s('sync_now')),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: s('account_section'),
            icon: Icons.verified_user_outlined,
            children: [
              _InfoTile(
                icon: Icons.person_outline,
                title: state.currentUser?.fullName.isNotEmpty == true
                    ? state.currentUser!.fullName
                    : state.currentUser?.email ?? '-',
                subtitle: state.currentUser?.email ?? '',
              ),
              const Divider(height: 1),
              _InfoTile(
                icon: Icons.admin_panel_settings_outlined,
                title: state.isAdmin ? s('admin_role') : s('cashier_role'),
                subtitle: s('current_role_label'),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => _changePassword(state),
                  icon: const Icon(Icons.password_outlined),
                  label: Text(
                    lang == 'ar' ? 'تغيير كلمة المرور' : 'Change Password',
                  ),
                ),
              ),
              if (isAdmin) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/administration'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(s('nav_administration')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.primary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _StoreNameTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isAdmin;
  final bool editing;
  final bool saving;
  final TextEditingController controller;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final String cancelLabel;

  const _StoreNameTile({
    required this.label,
    required this.value,
    required this.isAdmin,
    required this.editing,
    required this.saving,
    required this.controller,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 10),
            if (saving)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: Text(cancelLabel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onSave, child: Text(saveLabel)),
                ],
              ),
          ],
        ),
      );
    }

    return _InfoTile(
      icon: Icons.storefront_outlined,
      title: value,
      subtitle: label,
      trailing: isAdmin
          ? IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined))
          : null,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

class _SyncFacts extends StatelessWidget {
  final String pendingLabel;
  final int pendingCount;
  final String lastSyncedLabel;
  final String lastSynced;

  const _SyncFacts({
    required this.pendingLabel,
    required this.pendingCount,
    required this.lastSyncedLabel,
    required this.lastSynced,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _FactRow(
          label: pendingLabel,
          value: '$pendingCount',
          valueColor: pendingCount > 0 ? cs.error : Colors.green.shade700,
        ),
        const SizedBox(height: 8),
        _FactRow(label: lastSyncedLabel, value: lastSynced),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _FactRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncMessage extends StatelessWidget {
  final String message;
  final bool success;

  const _SyncMessage({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = success ? Colors.green.shade700 : cs.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: success ? Colors.green.shade800 : cs.error,
          height: 1.35,
        ),
      ),
    );
  }
}
