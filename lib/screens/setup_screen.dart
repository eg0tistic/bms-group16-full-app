import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../utils/constants.dart';
import '../widgets/brand_button.dart';

/// First-run owner setup used by release builds.
///
/// It deliberately has no skip path: every production database starts with a
/// unique administrator rather than credentials embedded in the application.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _storeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final existing = await db.getAllUsers(activeOnly: false);
      if (existing.isNotEmpty) {
        throw StateError('The business has already been configured.');
      }
      final id = await db.createUser(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        role: 'admin',
        fullName: _nameCtrl.text,
      );
      await db.setSetting(AppConstants.storeNameKey, _storeCtrl.text.trim());
      final user = await db.getUserById(id);
      if (user == null) throw StateError('Unable to open the new account.');
      if (!mounted) return;
      await context.read<AppState>().setCurrentUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ar = state.isArabic;
    String t(String arabic, String english) => ar ? arabic : english;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTokens.hero),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppTokens.brand,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('إعداد نظام الفوترة', 'Set up your billing system'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => state.setLanguage(ar ? 'en' : 'ar'),
                      child: Text(ar ? 'English' : 'العربية'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t('ابدأ بأمان', 'Start securely'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t(
                                  'أنشئ حساب المالك الأول. يمكنك إضافة الكاشير والمديرين لاحقاً.',
                                  'Create the first owner account. You can add cashiers and administrators later.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 24),
                              _field(
                                _storeCtrl,
                                t('اسم النشاط التجاري', 'Business name'),
                                Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                _nameCtrl,
                                t('اسم المالك', 'Owner name'),
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                _emailCtrl,
                                t('البريد الإلكتروني', 'Email address'),
                                Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                validator: (value) =>
                                    value != null && value.contains('@')
                                    ? null
                                    : t(
                                        'أدخل بريداً صحيحاً',
                                        'Enter a valid email',
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: InputDecoration(
                                  labelText: t('كلمة المرور', 'Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) => (value?.length ?? 0) >= 8
                                    ? null
                                    : t(
                                        'استخدم 8 أحرف على الأقل',
                                        'Use at least 8 characters',
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _finish(),
                                decoration: InputDecoration(
                                  labelText: t(
                                    'تأكيد كلمة المرور',
                                    'Confirm password',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                ),
                                validator: (value) =>
                                    value == _passwordCtrl.text
                                    ? null
                                    : t(
                                        'كلمتا المرور غير متطابقتين',
                                        'Passwords do not match',
                                      ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  style: TextStyle(color: cs.error),
                                ),
                              ],
                              const SizedBox(height: 24),
                              BrandButton(
                                label: t(
                                  'إنشاء وبدء الاستخدام',
                                  'Create and continue',
                                ),
                                loading: _saving,
                                onPressed: _finish,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty ? label : null,
    );
  }
}
