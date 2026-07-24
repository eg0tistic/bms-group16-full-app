import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../design/tokens.dart';
import '../utils/app_strings.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final cs = Theme.of(context).colorScheme;
    String s(String k) => AppStrings.get(k, lang);

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: _DrawerHeaderCard(
                appTitle: s('app_title'),
                email: state.currentUser?.email ?? '',
                role: state.isAdmin ? s('admin_role') : s('cashier_role'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: s('nav_home'),
                    route: '/home',
                  ),
                  _NavItem(
                    icon: Icons.people_outline,
                    label: s('nav_customers'),
                    route: '/customers',
                  ),
                  _NavItem(
                    icon: Icons.inventory_2_outlined,
                    label: s('nav_products'),
                    route: '/products',
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    label: s('nav_invoices'),
                    route: '/invoices',
                  ),
                  if (state.isAdmin)
                    _NavItem(
                      icon: Icons.query_stats_outlined,
                      label: s('nav_reports'),
                      route: '/reports',
                    ),
                  _NavItem(
                    icon: Icons.point_of_sale_outlined,
                    label: s('nav_cash_drawer'),
                    route: '/cash_drawer',
                  ),
                  _NavItem(
                    icon: Icons.electric_bolt_outlined,
                    label: s('nav_utility_bills'),
                    route: '/utility_bills',
                  ),
                  _NavItem(
                    icon: Icons.smart_toy_outlined,
                    label: s('nav_chatbot'),
                    route: '/chatbot',
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: s('nav_settings'),
                    route: '/settings',
                  ),
                  if (state.isAdmin)
                    _NavItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: s('nav_administration'),
                      route: '/administration',
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(Icons.logout, color: cs.error),
                title: Text(
                  s('nav_logout'),
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final appState = context.read<AppState>();
                  navigator.pop();
                  final confirmed = await showDialog<bool>(
                    context: navigator.context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(s('nav_logout')),
                      content: Text(s('logout_confirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(s('cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(s('yes')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await appState.logout();
                    if (navigator.mounted) {
                      navigator.pushReplacementNamed('/login');
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeaderCard extends StatelessWidget {
  final String appTitle;
  final String email;
  final String role;

  const _DrawerHeaderCard({
    required this.appTitle,
    required this.email,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTokens.hero,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTokens.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            appTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                role,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name == route;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        minLeadingWidth: 24,
        horizontalTitleGap: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: current,
        selectedTileColor: AppTokens.tealTint.withValues(alpha: 0.55),
        leading: Icon(
          icon,
          color: current ? AppTokens.tealDark : cs.onSurfaceVariant,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: current ? AppTokens.tealDark : cs.onSurface,
            fontWeight: current ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          if (!current) navigator.pushReplacementNamed(route);
        },
      ),
    );
  }
}
