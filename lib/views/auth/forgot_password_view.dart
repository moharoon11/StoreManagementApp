import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/workspace_ui.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  int _step = 0;
  String? _resetToken;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    if (username.length < 3 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _show('Enter your username and a valid store email address.');
      return;
    }
    final submitted =
        await context.read<AppProvider>().requestPasswordReset(username, email);
    if (!mounted) return;
    if (submitted) {
      setState(() => _step = 1);
    } else {
      _show(context.read<AppProvider>().errorMessage ?? 'Unable to submit the request.');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _show('Enter the 6-digit code from your email.');
      return;
    }
    final token = await context.read<AppProvider>().verifyPasswordResetOtp(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          otp,
        );
    if (!mounted) return;
    if (token != null) {
      setState(() {
        _resetToken = token;
        _step = 2;
      });
    } else {
      _show(context.read<AppProvider>().errorMessage ??
          'The verification code is invalid or expired.');
    }
  }

  Future<void> _resetPassword() async {
    if (_resetToken == null ||
        _passwordController.text.length < 8 ||
        _passwordController.text != _confirmPasswordController.text) {
      _show('Use matching passwords of at least 8 characters.');
      return;
    }
    final success = await context
        .read<AppProvider>()
        .resetPassword(_resetToken!, _passwordController.text);
    if (!mounted) return;
    if (success) {
      _show('Password changed. Sign in with your new password.');
      Navigator.of(context).pop();
    } else {
      _show(context.read<AppProvider>().errorMessage ??
          'This password reset request is invalid or expired.');
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppProvider>().isLoading;
    return Scaffold(
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SurfacePanel(child: _content(context, loading)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool loading) {
    switch (_step) {
      case 1:
        return _verifyForm(context, loading);
      case 2:
        return _newPasswordForm(context, loading);
      default:
        return _requestForm(context, loading);
    }
  }

  Widget _requestForm(BuildContext context, bool loading) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset password', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Enter the username and email saved in your store profile.'),
          const SizedBox(height: 20),
          TextField(
            controller: _usernameController,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _requestOtp(),
            decoration: const InputDecoration(
                labelText: 'Store email', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _requestOtp,
              child: Text(loading ? 'Sending...' : 'Send verification code'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: loading ? null : () => Navigator.of(context).pop(),
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      );

  Widget _verifyForm(BuildContext context, bool loading) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 42),
          const SizedBox(height: 16),
          Text('Enter verification code',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'If the details match an account, a 6-digit code was sent. It expires in 5 minutes.'),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _verifyOtp(),
            decoration: const InputDecoration(labelText: '6-digit code'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _verifyOtp,
              child: Text(loading ? 'Verifying...' : 'Verify code'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: loading ? null : _requestOtp,
              child: const Text('Resend code'),
            ),
          ),
        ],
      );

  Widget _newPasswordForm(BuildContext context, bool loading) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a new password',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Use a new password with at least 8 characters.'),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            onSubmitted: (_) => _resetPassword(),
            decoration: const InputDecoration(labelText: 'Confirm new password'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _resetPassword,
              child: Text(loading ? 'Saving...' : 'Change password'),
            ),
          ),
        ],
      );
}
