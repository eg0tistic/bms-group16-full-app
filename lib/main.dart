import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
// Picks the right SQLite backend per platform: FFI on desktop, the default
// factory on Android/iOS, and WebAssembly SQLite on web.
import 'data/db_factory_native.dart'
    if (dart.library.js_interop) 'data/db_factory_web.dart';
import 'data/demo_data.dart';
import 'data/database_helper.dart';
import 'design/app_theme.dart';
import 'utils/app_strings.dart';
import 'widgets/offline_banner.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/products_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/utility_bills_screen.dart';
import 'screens/administration_screen.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDatabaseFactory();
  // Evaluation builds keep the convenient sample dataset. Production builds
  // never ship a known administrator password: the owner creates the first
  // account through the setup screen instead.
  if (kDebugMode) await DemoData.seed();
  final needsSetup = (await DatabaseHelper.instance.getAllUsers(
    activeOnly: false,
  )).isEmpty;
  final appState = AppState();
  await appState.loadSavedState();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: BmsApp(needsSetup: needsSetup),
    ),
  );
}

class BmsApp extends StatelessWidget {
  const BmsApp({super.key, required this.needsSetup});

  final bool needsSetup;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return MaterialApp(
          title: AppStrings.get('app_title', state.language),
          debugShowCheckedModeBanner: false,
          locale: state.isArabic
              ? const Locale('ar', 'SD')
              : const Locale('en'),
          supportedLocales: const [Locale('ar', 'SD'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          builder: (context, child) => Column(
            children: [
              OfflineBanner(lang: state.language),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
          initialRoute: needsSetup
              ? '/setup'
              : (state.isLoggedIn ? '/home' : '/login'),
          routes: {
            '/setup': (_) => const SetupScreen(),
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const HomeScreen(),
            '/customers': (_) => const CustomersScreen(),
            '/products': (_) => const ProductsScreen(),
            '/invoices': (_) => const InvoicesScreen(),
            '/reports': (_) => const ReportsScreen(),
            '/settings': (_) => const SettingsScreen(),
            '/utility_bills': (_) => const UtilityBillsScreen(),
            '/administration': (_) => const AdministrationScreen(),
          },
        );
      },
    );
  }
}
