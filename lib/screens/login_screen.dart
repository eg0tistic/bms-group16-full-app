import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/database_helper.dart';
import '../design/tokens.dart';
import '../utils/app_strings.dart';
import '../widgets/brand_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final lang = context.read<AppState>().language;
    String s(String k) => AppStrings.get(k, lang);
    final appState = context.read<AppState>();

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = s('login_error_empty'));
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final user = await DatabaseHelper.instance.authenticateUser(
      email,
      password,
    );

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
        _error = s('login_error');
      });
      return;
    }

    await appState.setCurrentUser(user);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _showSudaPassInfo(String Function(String) s) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: cs.secondary),
            const SizedBox(width: 8),
            Expanded(child: Text(s('sudapass_title'))),
          ],
        ),
        content: Text(s('sudapass_info')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    String s(String k) => AppStrings.get(k, lang);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTokens.hero),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Language toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: const StadiumBorder(
                            side: BorderSide(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          final state = context.read<AppState>();
                          state.setLanguage(state.isArabic ? 'en' : 'ar');
                        },
                        icon: const Icon(
                          Icons.language,
                          color: Colors.white70,
                          size: 16,
                        ),
                        label: Text(lang == 'ar' ? 'English' : 'العربية'),
                      ),
                    ),
                  ),

                  // Brand mark + title
                  const SizedBox(height: 10),
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: AppTokens.brand,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                      boxShadow: AppTokens.glowTeal,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s('app_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s('login_subtitle'),
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 26),

                  // Bottom sheet card
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppTokens.rXl),
                            ),
                            boxShadow: AppTokens.shadowMd,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  s('login_title'),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 26),

                                // Email field
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: s('email'),
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password field
                                TextField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _login(),
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: s('password'),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                ),

                                // Error banner
                                if (_error.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: cs.error.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: cs.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error,
                                            style: TextStyle(
                                              color: cs.error,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 26),

                                // Login button (brand gradient)
                                BrandButton(
                                  label: s('login_btn'),
                                  loading: _loading,
                                  onPressed: _login,
                                ),
                                const SizedBox(height: 14),

                                // SudaPass placeholder: Sudan's national digital
                                // identity has no public API yet, so this only
                                // explains the plan — it never fakes a login flow.
                                OutlinedButton.icon(
                                  onPressed: () => _showSudaPassInfo(s),
                                  icon: Icon(
                                    Icons.fingerprint,
                                    size: 22,
                                    color: cs.secondary,
                                  ),
                                  label: Text(
                                    s('sudapass_btn'),
                                    style: TextStyle(
                                      color: cs.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    side: BorderSide(
                                      color: cs.secondary.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),

                                // Demo accounts hint — debug builds only, so the
                                // release build never exposes seed credentials.
                                if (kDebugMode) ...[
                                  const SizedBox(height: 28),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTokens.bg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTokens.border,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.science_outlined,
                                              size: 14,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              lang == 'ar'
                                                  ? 'حسابات تجريبية'
                                                  : 'Demo accounts',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          lang == 'ar'
                                              ? 'مدير: admin@bms.sd / admin123\nكاشير: cashier@bms.sd / cashier123'
                                              : 'Admin: admin@bms.sd / admin123\nCashier: cashier@bms.sd / cashier123',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
    );
  }
}
