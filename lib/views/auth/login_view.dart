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
    final provider = context.watch<AppProvider>();
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.canvas),
        child: SafeArea(
          child: Row(children: [
            if (isWide) const Expanded(flex: 11, child: _AuthStory()),
            Expanded(
              flex: isWide ? 9 : 1,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 52 : 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: AnimatedBuilder(
                      animation: _entrance,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                            0,
                            26 *
                                (1 -
                                    Curves.easeOutCubic
                                        .transform(_entrance.value))),
                        child: Opacity(opacity: _entrance.value, child: child),
                      ),
                      child: _AuthForm(
                        register: _isRegisterMode,
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        loading: provider.isLoading,
                        onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        onSubmit: _submit,
                        onSwitchMode: _toggleMode,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AuthStory extends StatelessWidget {
  const _AuthStory();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101A35), Color(0xFF243A89), AppColors.brand]),
        ),
        child: Stack(fit: StackFit.expand, children: [
          Positioned(
              top: -120,
              right: -80,
              child: _circle(320, const Color(0xFF82E9DE).withOpacity(.18))),
          Positioned(
              bottom: -180,
              left: -80,
              child: _circle(400, Colors.white.withOpacity(.08))),
          Padding(
            padding: const EdgeInsets.all(52),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Brand(onDark: true),
              const Spacer(),
              const Text('The calm way to\nrun your commerce.',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
                      height: 1.1,
                      fontSize: 44)),
              const SizedBox(height: 18),
              Text(
                  'One thoughtful workspace for checkout, stock, sales, and the decisions that keep your store moving.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(.74),
                      height: 1.55,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 36),
              const Wrap(spacing: 12, runSpacing: 12, children: [
                _StoryPill(icon: Icons.bolt_rounded, label: 'Fast checkout'),
                _StoryPill(icon: Icons.insights_rounded, label: 'Live insight'),
                _StoryPill(
                    icon: Icons.verified_user_outlined, label: 'Built to grow'),
              ]),
            ]),
          ),
        ]),
      );
  Widget _circle(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _AuthForm extends StatelessWidget {
  const _AuthForm(
      {required this.register,
      required this.usernameController,
      required this.passwordController,
      required this.obscurePassword,
      required this.loading,
      required this.onTogglePassword,
      required this.onSubmit,
      required this.onSwitchMode});
  final bool register, obscurePassword, loading;
  final TextEditingController usernameController, passwordController;
  final VoidCallback onTogglePassword, onSubmit, onSwitchMode;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Brand(),
        const SizedBox(height: 44),
        Text(register ? 'Start your workspace' : 'Welcome back',
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: AppColors.ink)),
        const SizedBox(height: 8),
        Text(
            register
                ? 'Set up your store command centre in moments.'
                : 'Sign in and pick up where your business left off.',
            style: const TextStyle(
                color: AppColors.muted,
                height: 1.5,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 26),
        TextField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Your workspace username',
                prefixIcon: Icon(Icons.person_outline_rounded))),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                  icon: Icon(obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                   onPressed: onTogglePassword)),
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
                                ? 'Create my workspace'
                                : 'Enter workspace'),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18)
                          ]))),
        const SizedBox(height: 18),
        Center(
            child: TextButton(
                onPressed: loading ? null : onSwitchMode,
                child: RichText(
                    text: TextSpan(
                        style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        children: [
                      TextSpan(
                          text: register
                              ? 'Already have a workspace? '
                              : 'New to Nexora? '),
                      TextSpan(
                          text: register ? 'Sign in' : 'Create one',
                          style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w800))
                    ])))),
      ]);
}

class _Brand extends StatelessWidget {
  const _Brand({this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: onDark ? Colors.white : AppColors.brand,
                borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.auto_graph_rounded,
                color: onDark ? AppColors.brand : Colors.white, size: 21)),
        const SizedBox(width: 11),
        Text('NEXORA',
            style: TextStyle(
                color: onDark ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 2)),
      ]);
}

class _StoryPill extends StatelessWidget {
  const _StoryPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.11),
          border: Border.all(color: Colors.white.withOpacity(.14)),
          borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF82E9DE), size: 17),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
      ]));
}
