import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'views/auth/login_view.dart';
import 'views/auth/welcome_view.dart';
import 'views/subscription/subscription_view.dart';
import 'views/store/store_profile_view.dart';
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
            title: 'BillMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.forOption(provider.themeOption),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: provider.isBootstrapping
                  ? const AppSplash(key: ValueKey('splash'))
                  : provider.isAuthenticated
                      ? provider.hasCompletedStoreSetup
                          ? provider.hasSubscriptionAccess
                              ? const ResponsiveLayout(key: ValueKey('app'))
                              : const SubscriptionView(
                                  key: ValueKey('subscription'))
                          : provider.hasSubscriptionAccess
                              ? const StoreProfileView(
                                  key: ValueKey('store-setup'),
                                  setupRequired: true,
                                )
                              : const SubscriptionView(
                                  key: ValueKey('subscription'))
                      : provider.hasSeenWelcome
                          ? const LoginView(key: ValueKey('auth'))
                          : const WelcomeView(key: ValueKey('welcome')),
            ),
          );
        },
      ),
    );
  }
}
