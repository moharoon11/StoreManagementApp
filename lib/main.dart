import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'views/auth/login_view.dart';
import 'widgets/responsive_layout.dart';
import 'widgets/app_splash.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoreManagementApp());
}

class StoreManagementApp extends StatelessWidget {
  const StoreManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Nexora Commerce',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.forOption(provider.themeOption),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: provider.isBootstrapping
                  ? const AppSplash(key: ValueKey('splash'))
                  : provider.isAuthenticated
                      ? const ResponsiveLayout(key: ValueKey('app'))
                      : const LoginView(key: ValueKey('auth')),
            ),
          );
        },
      ),
    );
  }
}
