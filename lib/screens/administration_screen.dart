import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../models/app_user.dart';
import '../utils/app_strings.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';

class AdministrationScreen extends StatefulWidget {
  const AdministrationScreen({super.key});

  @override
  State<AdministrationScreen> createState() => _AdministrationScreenState();
}

class _AdministrationScreenState extends State<AdministrationScreen> {
  bool _loading = true;
  List<AppUser> _users = const [];
  List<Map<String, dynamic>> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final values = await Future.wait([
      db.getAllUsers(activeOnly: false),
      db.getAuditLogs(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = values[0] as List<AppUser>;
      _logs = values[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<void> _openUserForm({AppUser? user}) async {
    final state = context.read<AppState>();
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog(
        user: user,
        actorUserId: state.currentUser?.id,
        lang: state.language,
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final ar = lang == 'ar';
    if (!state.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.get('administration_title', lang)),
        ),
        drawer: const AppDrawer(),
        body: Center(child: Text(AppStrings.get('admin_only', lang))),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.get('administration_title', lang)),
          bottom: TabBar(
            tabs: [
              Tab(text: ar ? 'المستخدمون' : 'Users'),
              Tab(text: ar ? 'سجل التدقيق' : 'Audit Log'),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        drawer: const AppDrawer(),
        floatingActionButton: Builder(
          builder: (tabContext) {
            final controller = DefaultTabController.of(tabContext);
            return AnimatedBuilder(
              animation: controller,
              builder: (_, _) => controller.index == 0
                  ? FloatingActionButton.extended(
                      onPressed: () => _openUserForm(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(ar ? 'مستخدم جديد' : 'New User'),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _UsersList(
                    users: _users,
                    currentUserId: state.currentUser?.id,
                    lang: lang,
                    onEdit: (u) => _openUserForm(user: u),
                  ),
                  _AuditList(logs: _logs, lang: lang),
                ],
              ),
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final List<AppUser> users;
  final int? currentUserId;
  final String lang;
  final ValueChanged<AppUser> onEdit;

  const _UsersList({
    required this.users,
    required this.currentUserId,
    required this.lang,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ar = lang == 'ar';
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: ar ? 'لا يوجد مستخدمون' : 'No users',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final user = users[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                user.fullName.trim().isEmpty
                    ? user.email.characters.first.toUpperCase()
                    : user.fullName.characters.first,
              ),
            ),
            title: Text(user.fullName.isEmpty ? user.email : user.fullName),
            subtitle: Text(
              '${user.email}\n${user.role == 'admin' ? (ar ? 'مدير' : 'Admin') : (ar ? 'كاشير' : 'Cashier')}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isActive ? Icons.check_circle : Icons.block,
                  color: user.isActive ? Colors.green : Colors.red,
                  size: 20,
                ),
                IconButton(
                  tooltip: ar ? 'تعديل' : 'Edit',
                  onPressed: () => onEdit(user),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuditList extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final String lang;

  const _AuditList({required this.logs, required this.lang});

  @override
  Widget build(BuildContext context) {
    final ar = lang == 'ar';
    if (logs.isEmpty) {
      return EmptyState(
        icon: Icons.history_outlined,
        title: ar ? 'لا توجد أحداث بعد' : 'No audit events yet',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final log = logs[i];
        var details = '';
        final raw = log['details'] as String?;
        if (raw?.isNotEmpty == true) {
          try {
            details = const JsonEncoder.withIndent(
              '  ',
            ).convert(jsonDecode(raw!));
          } catch (_) {
            details = raw!;
          }
        }
        return Card(
          child: ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text('${log['action']} · ${log['entity_type']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['user_name'] ?? log['user_email'] ?? (ar ? 'النظام' : 'System')} · '
                  '${Fmt.dateTime(log['created_at'] as String?)}',
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(
                        details,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            isThreeLine: details.isNotEmpty,
          ),
        );
      },
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final AppUser? user;
  final int? actorUserId;
  final String lang;

  const _UserFormDialog({
    this.user,
    required this.actorUserId,
    required this.lang,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _role;
  late bool _active;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.fullName ?? '');
    _email = TextEditingController(text: widget.user?.email ?? '');
    _role = widget.user?.role ?? 'cashier';
    _active = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final db = DatabaseHelper.instance;
      if (widget.user == null) {
        await db.createUser(
          email: _email.text,
          password: _password.text,
          role: _role,
          fullName: _name.text,
          actorUserId: widget.actorUserId,
        );
      } else {
        await db.updateUserProfile(
          id: widget.user!.id!,
          email: _email.text,
          fullName: _name.text,
          role: _role,
          isActive: _active,
          actorUserId: widget.actorUserId,
        );
        if (_password.text.isNotEmpty) {
          final changed = await db.changePassword(
            userId: widget.user!.id!,
            currentPassword: '',
            newPassword: _password.text,
            actorUserId: widget.actorUserId,
            requireCurrentPassword: false,
          );
          if (!changed) throw StateError('Password is too short.');
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is StateError
              ? e.message
              : (widget.lang == 'ar'
                    ? 'تعذر الحفظ. تحقق من البريد وكلمة المرور.'
                    : 'Could not save. Check the email and password.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    final editing = widget.user != null;
    return AlertDialog(
      title: Text(
        editing
            ? (ar ? 'تعديل المستخدم' : 'Edit User')
            : (ar ? 'مستخدم جديد' : 'New User'),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: ar ? 'الاسم' : 'Name'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? (ar ? 'مطلوب' : 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: ar ? 'البريد' : 'Email',
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? (ar ? 'بريد غير صالح' : 'Invalid email')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: editing
                        ? (ar
                              ? 'كلمة مرور جديدة (اختياري)'
                              : 'New password (optional)')
                        : (ar ? 'كلمة المرور' : 'Password'),
                    helperText: ar
                        ? '8 أحرف على الأقل'
                        : 'At least 8 characters',
                  ),
                  validator: (v) {
                    if (!editing && (v == null || v.length < 8)) {
                      return ar ? '8 أحرف على الأقل' : 'At least 8 characters';
                    }
                    if (editing && v != null && v.isNotEmpty && v.length < 8) {
                      return ar ? '8 أحرف على الأقل' : 'At least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: InputDecoration(labelText: ar ? 'الدور' : 'Role'),
                  items: [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(ar ? 'مدير' : 'Admin'),
                    ),
                    DropdownMenuItem(
                      value: 'cashier',
                      child: Text(ar ? 'كاشير' : 'Cashier'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'cashier'),
                ),
                if (editing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ar ? 'حساب فعال' : 'Active account'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                if (_error.isNotEmpty)
                  Text(
                    _error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(ar ? 'حفظ' : 'Save'),
        ),
      ],
    );
  }
}
