import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _entrance;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your username and password.')));
      return;
    }
    final provider = context.read<AppProvider>();
    final success = _isRegisterMode
        ? await provider.register(username, password)
        : await provider.login(username, password);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.errorMessage ??
              'We could not sign you in. Please try again.')));
    }
  }

  void _toggleMode() => setState(() {
        _isRegisterMode = !_isRegisterMode;
        _entrance
          ..reset()
          ..forward();
      });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: scheme.brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWide ? 40 : 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 880 : 440),
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, child) =>
                    Opacity(opacity: _entrance.value, child: child),
                child: isWide
                    ? IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(flex: 5, child: _LedgerPanel()),
                              Expanded(
                                flex: 6,
                                child: _LedgerCard(
                                  roundedLeft: false,
                                  child: _AuthForm(
                                    register: _isRegisterMode,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    obscurePassword: _obscurePassword,
                                    loading: provider.isLoading,
                                    onTogglePassword: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    onSubmit: _submit,
                                    onSwitchMode: _toggleMode,
                                  ),
                                ),
                              ),
                            ]),
                      )
                    : _LedgerCard(
                        child: _AuthForm(
                          register: _isRegisterMode,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          loading: provider.isLoading,
                          onTogglePassword: () => setState(() =>
                              _obscurePassword = !_obscurePassword),
                          onSubmit: _submit,
                          onSwitchMode: _toggleMode,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark forest side panel with brass rules (wide screens only).
class _LedgerPanel extends StatelessWidget {
  const _LedgerPanel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(34),
        decoration: const BoxDecoration(
          color: Color(0xFF10281E),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0B45C),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.account_balance_outlined,
                    color: Color(0xFF10281E), size: 20)),
            const SizedBox(width: 10),
            const Text('NEXORA',
                style: TextStyle(
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white)),
          ]),
          const Spacer(),
          Container(height: 3, width: 44, color: const Color(0xFFE0B45C)),
          const SizedBox(height: 14),
          const Text('The day book,\nkept properly.',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  fontSize: 30)),
          const SizedBox(height: 12),
          Text('Billing, shelves and takings \u2014 ruled lines, no clutter.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .65),
                  height: 1.55,
                  fontSize: 13)),
          const SizedBox(height: 26),
          for (final row in const [
            (Icons.receipt_long_outlined, 'Bills in seconds'),
            (Icons.inventory_2_outlined, 'Shelves always counted'),
            (Icons.auto_graph_outlined, 'Takings at a glance'),
          ]) ...[
            Row(children: [
              Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(row.$1,
                      color: const Color(0xFFE0B45C), size: 14)),
              const SizedBox(width: 10),
              Text(row.$2,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
          ],
        ]),
      );
}

/// White ruled card holding the form.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.child, this.roundedLeft = true});
  final Widget child;
  final bool roundedLeft;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: roundedLeft
            ? BorderRadius.circular(12)
            : const BorderRadius.horizontal(right: Radius.circular(12)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ]),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.register,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSwitchMode,
  });
  final bool register;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SIGN IN',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(register ? 'Open your ledger' : 'Welcome back',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              register
                  ? 'Create an account to start keeping the books.'
                  : 'Sign in to continue keeping the books.',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .6),
                  fontSize: 13)),
          const SizedBox(height: 22),
          Text('USERNAME',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 10.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              hintText: 'e.g. counter-one',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Text('PASSWORD',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 10.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Text(register
                                ? 'Create my ledger'
                                : 'Open my ledger'),
                            const SizedBox(width: 8),
                            const Icon(Icons.east_rounded, size: 18)
                          ]))),
          const SizedBox(height: 14),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 6),
          Center(
              child: TextButton(
                  onPressed: loading ? null : onSwitchMode,
                  child: RichText(
                      text: TextSpan(
                          style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: .6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          children: [
                        TextSpan(
                            text: register
                                ? 'Already keeping books? '
                                : 'New to Nexora? '),
                        TextSpan(
                            text: register ? 'Sign in' : 'Create one',
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800))
                      ])))),
        ]);
  }
}
