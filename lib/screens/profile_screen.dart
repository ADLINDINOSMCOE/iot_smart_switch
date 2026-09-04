import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final AuthService? authService;
  final NotificationService? notificationService;

  const ProfileScreen({
    super.key,
    required this.user,
    this.authService,
    this.notificationService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService;
  late final NotificationService _notificationService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.instance;
    _notificationService =
        widget.notificationService ?? NotificationService.instance;
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access switch controls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _notificationService.unregisterDeviceToken(widget.user.uid);
        await _authService.signOut();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSendPasswordReset() async {
    final email = widget.user.email;
    if (email == null || email.isEmpty) return;

    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email dispatched to $email.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleSendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email dispatched. Please check your inbox.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and will delete your stored device token profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _authService.deleteAccount();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email = user.email ?? 'No email provided';
    final displayName = user.displayName ?? (email.contains('@') ? email.split('@').first : 'User');
    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    final isEmailVerified = user.emailVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: AppTheme.primaryColor.withAlpha(40),
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(
                          label: isGoogle ? 'GOOGLE AUTH' : 'EMAIL / PASSWORD',
                          type: StatusType.info,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Details
                  CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Security & Verification',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Email Verification:',
                                style: TextStyle(fontSize: 13, color: Colors.grey)),
                            StatusBadge(
                              label: isEmailVerified ? 'VERIFIED' : 'UNVERIFIED',
                              type: isEmailVerified
                                  ? StatusType.success
                                  : StatusType.warning,
                            ),
                          ],
                        ),
                        if (!isEmailVerified && !isGoogle) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                            label: const Text('Send Verification Email'),
                            onPressed: _handleSendEmailVerification,
                          ),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('User UID:',
                                style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text(
                              user.uid.length > 12
                                  ? '${user.uid.substring(0, 10)}...'
                                  : user.uid,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Management (for Email/Password accounts)
                  if (!isGoogle) ...[
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password Management',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Need to update your password? Send a secure reset link to your registered email address.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lock_reset_outlined, size: 18),
                            label: const Text('Send Password Reset Email'),
                            onPressed: _handleSendPasswordReset,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sign Out Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Sign Out'),
                      onPressed: _isLoading ? null : _handleSignOut,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delete Account Action
                  TextButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined,
                        size: 18, color: AppTheme.errorColor),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    onPressed: _isLoading ? null : _handleDeleteAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
