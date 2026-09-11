import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Color.lerp(Theme.of(context).scaffoldBackgroundColor, scheme.primary, .10) ??
                  Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -50,
              child: _AuthOrb(
                size: 220,
                color: scheme.primary.withValues(alpha: .10),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -20,
              child: _AuthOrb(
                size: 180,
                color: scheme.secondary.withValues(alpha: .10),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(flex: 6, child: _AuthStory()),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 4,
                                child: _AnimatedAuthCard(
                                  animation: _entrance,
                                  child: _AuthForm(
                                    register: _isRegisterMode,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    obscurePassword: _obscurePassword,
                                    loading: provider.isLoading,
                                    onTogglePassword: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    onSubmit: _submit,
                                    onSwitchMode: _toggleMode,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              const SizedBox(
                                height: 250,
                                child: _AuthStory(compact: true),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _AnimatedAuthCard(
                                  animation: _entrance,
                                  child: _AuthForm(
                                    register: _isRegisterMode,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    obscurePassword: _obscurePassword,
                                    loading: provider.isLoading,
                                    onTogglePassword: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    onSubmit: _submit,
                                    onSwitchMode: _toggleMode,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        offset: Offset(0, 24 * (1 - Curves.easeOutCubic.transform(animation.value))),
        child: Opacity(opacity: animation.value, child: childWidget),
      ),
      child: SurfacePanel(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}

class _AuthStory extends StatelessWidget {
  const _AuthStory({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF201E21),
            Color(0xFF5E452D),
            Color(0xFF7A5A3A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_graph_rounded, color: AppColors.bronze),
              ),
              const SizedBox(width: 12),
              Text(
                'NEXORA',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            compact
                ? 'A sharper workspace for commerce.'
                : 'A sharper workspace for billing, inventory, and store operations.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 28 : 38,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'The new layout removes the welcome step and opens straight into a calmer operating view.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .78),
                ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _StoryPill(label: 'Direct workspace entry'),
              _StoryPill(label: 'Compact operational layout'),
              _StoryPill(label: 'Responsive sales screens'),
            ],
          ),
        ],
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
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSwitchMode,
  });

  final bool register;
  final bool obscurePassword;
  final bool loading;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          register ? 'Create your workspace' : 'Welcome back',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          register
              ? 'Set up your store command centre and start operating right away.'
              : 'Sign in and return directly to the workspace.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .66),
              ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Your workspace username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onTogglePassword,
            ),
          ),
        ),
        const SizedBox(height: 18),
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
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              loading
                  ? 'Please wait...'
                  : register
                      ? 'Create account'
                      : 'Enter workspace',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: loading ? null : onSwitchMode,
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                children: [
                  TextSpan(
                    text: register
                        ? 'Already have an account? '
                        : 'New to Nexora? ',
                  ),
                  TextSpan(
                    text: register ? 'Sign in' : 'Create one',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryPill extends StatelessWidget {
  const _StoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
            ),
      ),
    );
  }
}

class _AuthOrb extends StatelessWidget {
  const _AuthOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
