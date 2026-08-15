import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../services/sync_engine.dart';

class AccountPage extends StatefulWidget {
  const AccountPage(
      {super.key,
      required this.controller,
      this.onSync,
      this.onSignOut,
      this.onImportGuestData,
      this.onCountGuestData,
      this.onResolveConflict});

  final AuthController controller;
  final Future<SyncReport> Function()? onSync;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onImportGuestData;
  final Future<GuestDataCount> Function()? onCountGuestData;
  final Future<ConflictChoice?> Function(String entityType, String title,
      String localSummary, String remoteSummary)? onResolveConflict;

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

  Widget _signedIn(BuildContext context, AuthController controller) {
    final id = controller.session?.userId ?? '';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Account', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Signed in as $id'),
      const SizedBox(height: 24),
      _buildSyncSection(context),
      const SizedBox(height: 24),
      _buildDataSection(context),
    ]);
  }

  Widget _buildSyncSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sync',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      FilledButton.icon(
          key: const Key('account-sync-button'),
          onPressed: () => _syncWithConflictUI(context),
          icon: const Icon(Icons.sync),
          label: const Text('Sync now')),
      const SizedBox(height: 8),
      _guestImportBanner(context),
    ]);
  }

  Widget _guestImportBanner(BuildContext context) {
    return FutureBuilder<GuestDataCount>(
      future: _countGuestData(),
      builder: (context, snapshot) {
        final count = snapshot.data;
        if (count == null || (count.taskCount == 0 && count.noteCount == 0)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xffdff3ed),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.folder_open, color: Color(0xff157a6e)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have ${count.taskCount} task(s) and ${count.noteCount} note(s) from guest mode. Import them?',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _importGuestData(context),
                child: const Text('Import'),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Data',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('account-export-button'),
        onPressed: () => _exportData(context),
        icon: const Icon(Icons.download),
        label: const Text('Export all data (JSON)'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          key: const Key('account-signout-button'),
          onPressed: widget.onSignOut ?? widget.controller.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out')),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('account-delete-button'),
        onPressed: () => _confirmDeleteAccount(context),
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        label:
            const Text('Delete account', style: TextStyle(color: Colors.red)),
      ),
    ]);
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

  Future<void> _syncWithConflictUI(BuildContext context) async {
    try {
      final report = await widget.onSync?.call();
      if (report == null || !context.mounted) return;
      final message = report.conflicts > 0
          ? 'Sync complete: pulled ${report.pulled}, pushed ${report.pushed}, ${report.conflicts} conflict(s). Tap to review.'
          : 'Sync complete: pulled ${report.pulled}, pushed ${report.pushed}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        action: report.conflicts > 0
            ? SnackBarAction(
                label: 'Review',
                onPressed: () => _showConflictReview(context, report),
              )
            : null,
      ));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    }
  }

  Future<void> _showConflictReview(
      BuildContext context, SyncReport report) async {
    // Conflict resolution is driven by the sync engine reporting
    // individual conflicts. The widget callbacks handle each one.
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync conflicts'),
        content: Text(
            '${report.conflicts} item(s) were modified on both devices.\n\n'
            'The cloud version was kept for each conflicting item. '
            'Your local version is still available in the app.\n\n'
            'To resolve, review the items and manually merge changes.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final data = await widget.controller.client.exportMyData();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export ready'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(data),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This action is permanent. All your tasks, notes, preferences, '
          'and device registrations will be deleted from the cloud. '
          'Local data will remain on this device until you sign out or '
          'clear app data.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.controller.client.deleteMyAccount();
      await widget.controller.signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Account deleted.')));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deletion failed: $error')));
    }
  }

  Future<void> _importGuestData(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import guest data'),
        content: const Text(
          'This will merge your guest tasks and notes into your account. '
          'Existing items with the same ID will be skipped.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (result != true || !context.mounted) return;
    await widget.onImportGuestData?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Guest data imported.')));
    setState(() {});
  }

  Future<GuestDataCount> _countGuestData() async {
    try {
      return await widget.onCountGuestData?.call() ??
          const GuestDataCount(taskCount: 0, noteCount: 0);
    } on Object {
      return const GuestDataCount(taskCount: 0, noteCount: 0);
    }
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

class GuestDataCount {
  const GuestDataCount({required this.taskCount, required this.noteCount});
  final int taskCount;
  final int noteCount;
}

class ConflictResolver {
  static Future<ConflictChoice?> show(
    BuildContext context, {
    required String entityType,
    required String title,
    required String localSummary,
    required String remoteSummary,
  }) {
    return showDialog<ConflictChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sync conflict: $entityType'),
        content: SizedBox(
          width: 420,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"$title" was changed on both devices.',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Text('This device',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(localSummary,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                const Text('Cloud',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(remoteSummary,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.keepLocal),
            child: const Text('Keep mine'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.takeRemote),
            child: const Text('Take cloud'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.keepBoth),
            child: const Text('Keep both'),
          ),
        ],
      ),
    );
  }
}

enum ConflictChoice { keepLocal, takeRemote, keepBoth }
