import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/workspace_ui.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  bool _shareLocation = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid store email address.')),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    final submitted = await provider.requestPasswordReset(email,
        shareLocation: _shareLocation);
    if (!mounted) return;
    if (submitted) {
      setState(() => _submitted = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(provider.errorMessage ?? 'Unable to submit the request.')),
      );
    }
  }

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
                child: SurfacePanel(
                    child: _submitted
                        ? _success(context)
                        : _form(context, loading)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 42),
          const SizedBox(height: 16),
          Text('Check your email',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'If this email is registered, a password-reset link will arrive shortly. Check spam or junk mail too.'),
          const SizedBox(height: 24),
          TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to sign in')),
        ],
      );

  Widget _form(BuildContext context, bool loading) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset password',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Enter the email saved in your store profile. For privacy, the confirmation is the same whether or not the email is registered.'),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _sendLink(),
            decoration: const InputDecoration(
                labelText: 'Store email',
                prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _shareLocation,
            onChanged: loading
                ? null
                : (value) => setState(() => _shareLocation = value ?? false),
            title: const Text('Include my approximate GPS location'),
            subtitle: const Text(
                'Optional. Permission is requested only if selected.'),
          ),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: loading ? null : _sendLink,
                  child: Text(loading ? 'Sending...' : 'Send reset link'))),
          const SizedBox(height: 8),
          Center(
              child: TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Back to sign in'))),
        ],
      );
}
