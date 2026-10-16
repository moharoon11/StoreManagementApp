import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/workspace_ui.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key, required this.token});
  final String token;
  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token.isEmpty ||
        _password.text.length < 8 ||
        _password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Use matching passwords of at least 8 characters.')));
      return;
    }
    final provider = context.read<AppProvider>();
    final success = await provider.resetPassword(widget.token, _password.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Password changed. Sign in with your new password.'
            : provider.errorMessage ??
                'This reset link is invalid or expired.')));
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppProvider>().isLoading;
    return Scaffold(
        body: WorkspaceBackdrop(
            child: SafeArea(
                child: Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SurfacePanel(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Choose a new password',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                    'This link can be used once and expires after one hour.'),
                const SizedBox(height: 20),
                TextField(
                    controller: _password,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'New password')),
                const SizedBox(height: 12),
                TextField(
                    controller: _confirm,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                        labelText: 'Confirm new password')),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: loading ? null : _submit,
                        child:
                            Text(loading ? 'Saving...' : 'Change password'))),
              ]))),
    ))));
  }
}
