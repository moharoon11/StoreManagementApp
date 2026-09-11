import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/workspace_ui.dart';

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
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
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
        const SnackBar(content: Text('Enter your username and password.')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final success = _isRegisterMode
        ? await provider.register(username, password)
        : await provider.login(username, password);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'We could not sign you in. Please try again.',
          ),
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _entrance
        ..reset()
        ..forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 18,
                vertical: compact ? 12 : 18,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 392 : 1120),
                child: Column(
                  children: [
                    if (wide) ...[
                      const _BrandStrip(),
                      const SizedBox(height: 18),
                    ] else ...[
                      const _CompactAuthHeader(),
                      const SizedBox(height: 14),
                    ],
                    wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _AnimatedAuthCard(
                                  animation: _entrance,
                                  child: _AuthForm(
                                    register: _isRegisterMode,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    obscurePassword: _obscurePassword,
                                    loading: provider.isLoading,
                                    compact: false,
                                    onTogglePassword: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    onSubmit: _submit,
                                    onSwitchMode: _toggleMode,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              const Expanded(
                                flex: 4,
                                child: _WorkspaceSnapshot(),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _AnimatedAuthCard(
                                animation: _entrance,
                                child: _AuthForm(
                                  register: _isRegisterMode,
                                  usernameController: _usernameController,
                                  passwordController: _passwordController,
                                  obscurePassword: _obscurePassword,
                                  loading: provider.isLoading,
                                  compact: true,
                                  onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  onSubmit: _submit,
                                  onSwitchMode: _toggleMode,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandStrip extends StatelessWidget {
  const _BrandStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final badges = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatusPill(label: 'Cross-platform UI', color: scheme.primary),
              StatusPill(label: 'Desktop-ready flow', color: scheme.secondary),
              StatusPill(label: 'Responsive billing', color: scheme.tertiary),
            ],
          );

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXORA',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Retail operations, redesigned to feel crisp on both phone and desktop.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 14),
                badges,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 18),
              Flexible(child: badges),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedAuthCard extends StatelessWidget {
  const _AnimatedAuthCard({
    required this.animation,
    required this.child,
  });

  final AnimationController animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, childWidget) => Transform.translate(
        offset: Offset(
          0,
          24 * (1 - Curves.easeOutCubic.transform(animation.value)),
        ),
        child: Opacity(opacity: animation.value, child: childWidget),
      ),
      child: SurfacePanel(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(2),
          child: child,
        ),
      ),
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
    required this.compact,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSwitchMode,
  });

  final bool register;
  final bool obscurePassword;
  final bool loading;
  final bool compact;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          StatusPill(
            label: register ? 'Create account' : 'Store access',
            color: scheme.primary,
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 2),
        Text(
          compact
              ? (register ? 'Create account' : 'Sign in')
              : (register ? 'Create your workspace' : 'Welcome back'),
          style: compact
              ? Theme.of(context).textTheme.headlineSmall
              : Theme.of(context).textTheme.headlineMedium,
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            register
                ? 'Set up your login and start billing.'
                : 'Sign in to continue.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .7),
                ),
          ),
        ],
        SizedBox(height: compact ? 14 : 20),
        TextField(
          controller: usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 16 : 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    register
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                    size: 18,
                  ),
            label: Text(
              loading
                  ? 'Please wait...'
                  : register
                      ? 'Create account'
                      : 'Sign in',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: loading ? null : onSwitchMode,
            child: Text(
              register
                  ? 'Already have an account? Sign in'
                  : 'Need a new account? Create one',
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactAuthHeader extends StatelessWidget {
  const _CompactAuthHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Nexora Commerce',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceSnapshot extends StatelessWidget {
  const _WorkspaceSnapshot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SectionPanel(
          title: 'What changed',
          subtitle:
              'The app now opens into a sharper, more structured experience built to behave consistently on larger screens.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SnapshotLine(
                icon: Icons.desktop_windows_outlined,
                label: 'Desktop-friendly panels and navigation',
              ),
              SizedBox(height: 12),
              _SnapshotLine(
                icon: Icons.shopping_bag_outlined,
                label: 'Cleaner checkout and cart surfaces',
              ),
              SizedBox(height: 12),
              _SnapshotLine(
                icon: Icons.image_outlined,
                label: 'File selection that behaves properly on Windows',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdaptiveWrapGrid(
          minItemWidth: 180,
          children: [
            _SnapshotMetric(
              label: 'Platform',
              value: 'Android + Windows',
              accent: scheme.primary,
            ),
            _SnapshotMetric(
              label: 'Style',
              value: 'Modern control center',
              accent: scheme.secondary,
            ),
            _SnapshotMetric(
              label: 'Goal',
              value: 'Keep functionality intact',
              accent: scheme.tertiary,
            ),
          ],
        ),
      ],
    );
  }
}

class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SurfacePanel(
      padding: const EdgeInsets.all(14),
      color: accent.withValues(alpha: .06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .58),
                  letterSpacing: 1.4,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
