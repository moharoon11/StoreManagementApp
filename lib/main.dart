import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'views/auth/login_view.dart';
import 'widgets/responsive_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoreManagementApp());
}

class StoreManagementApp extends StatelessWidget {
  const StoreManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

          return MaterialApp(
            title: 'Store POS & Billing System',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF2563EB), // Vibrant Royal Blue
                secondary: Color(0xFF0EA5E9),
                surface: Color(0xFFFFFFFF),
                background: Color(0xFFF8FAFC),
                onPrimary: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF0F172A),
                elevation: 0,
                centerTitle: false,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
              textTheme: baseTextTheme.apply(
                bodyColor: const Color(0xFF0F172A),
                displayColor: const Color(0xFF0F172A),
              ),
            ),
            home: provider.isAuthenticated ? const ResponsiveLayout() : const LoginView(),
          );
        },
      ),
    );
  }
}
