import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'views/auth/login_view.dart';
import 'widgets/responsive_layout.dart';
import 'widgets/app_splash.dart';
import 'theme/app_theme.dart';
import 'widgets/workday_welcome.dart';

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
                      ? const AuthenticatedFlow(key: ValueKey('app'))
                      : const LoginView(key: ValueKey('auth')),
            ),
          );
        },
      ),
    );
  }
}

class AuthenticatedFlow extends StatefulWidget {
  const AuthenticatedFlow({super.key});

  @override
  State<AuthenticatedFlow> createState() => _AuthenticatedFlowState();
}

class _AuthenticatedFlowState extends State<AuthenticatedFlow> {
  bool _atWelcome = true;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        child: _atWelcome
            ? WorkdayWelcome(
                key: const ValueKey('workday-welcome'),
                onContinue: () => setState(() => _atWelcome = false))
            : const ResponsiveLayout(key: ValueKey('workspace')),
      );
}
