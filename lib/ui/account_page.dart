import 'package:flutter/material.dart';

import '../services/auth_controller.dart';

class AccountPage extends StatefulWidget {
  const AccountPage(
      {super.key, required this.controller, this.onSync, this.onSignOut});

  final AuthController controller;
  final Future<void> Function()? onSync;
  final Future<void> Function()? onSignOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool registerMode = false;
  String? validationError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;
    if (controller.status == AuthStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.status == AuthStatus.signedIn) {
      return _signedIn(context, controller);
    }
    if (controller.status == AuthStatus.needsEmailConfirmation) {
      return _confirmation(context);
    }
    return _form(context, controller);
  }

  Widget _form(BuildContext context, AuthController controller) {
    final error = validationError ?? controller.errorMessage;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(registerMode ? 'Create account' : 'Sign in',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Your local schedule and notes stay available offline.'),
        const SizedBox(height: 24),
        TextField(
            key: const Key('account-email-field'),
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(
            key: const Key('account-password-field'),
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password')),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
            key: const Key('account-submit-button'),
            onPressed: () => _submit(controller),
            icon: Icon(registerMode ? Icons.person_add : Icons.login),
            label: Text(registerMode ? 'Create account' : 'Sign in')),
        TextButton.icon(
            onPressed: () => setState(() {
                  registerMode = !registerMode;
                  validationError = null;
                }),
            icon: const Icon(Icons.swap_horiz),
            label: Text(registerMode
                ? 'Already have an account?'
                : 'Create an account')),
      ],
    );
  }

  Widget _confirmation(BuildContext context) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.mark_email_read_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Check your email to confirm the account.'),
              TextButton(
                  onPressed: () {
                    widget.controller.dismissEmailConfirmation();
                    setState(() => registerMode = false);
                  },
                  child: const Text('Back to sign in')),
            ])));
  }

  Widget _signedIn(BuildContext context, AuthController controller) {
    final id = controller.session?.userId ?? '';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Account', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Signed in as $id'),
      const SizedBox(height: 24),
      FilledButton.icon(
          key: const Key('account-sync-button'),
          onPressed: widget.onSync,
          icon: const Icon(Icons.sync),
          label: const Text('Sync now')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          key: const Key('account-signout-button'),
          onPressed: widget.onSignOut ?? controller.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out')),
    ]);
  }

  Future<void> _submit(AuthController controller) async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (!email.contains('@') || password.length < 8) {
      setState(() => validationError =
          'Enter a valid email and a password of at least 8 characters.');
      return;
    }
    setState(() => validationError = null);
    if (registerMode) {
      await controller.signUp(email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
  }
}
