import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isUpdating = false;

  static const Color backgroundColor = Color(0xFF071C2D);
  static const Color cardColor = Color(0xFF102B40);
  static const Color borderColor = Color(0xFF1D394D);
  static const Color textColor = Color(0xFFE8EEF3);
  static const Color secondaryTextColor = Color(0xFF8999A6);
  static const Color primaryColor = Color(0xFF5AA9FF);

  void _showEditProfileDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Display Name',
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: const TextStyle(color: Color(0xFF5B6C7A)),
                    filled: true,
                    fillColor: const Color(0xFF0D2234),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: primaryColor),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE45B5B)),
                    ),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Please enter a name';
                    if (trimmed.length > 60) return 'Name must be under 60 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newName = controller.text.trim();

                Navigator.pop(dialogContext);
                setState(() => _isUpdating = true);

                try {
                  await _authService.updateUserProfile(displayName: newName);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: Color(0xFF1B4332),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: const Color(0xFF581818),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isUpdating = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: const Color(0xFF1B4332),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: $e'),
          backgroundColor: const Color(0xFF581818),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to log out of your IoT Smart Switch account?',
            style: TextStyle(color: secondaryTextColor, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _authService.signOut();

                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFE45B5B), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Color(0xFFE45B5B), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account? All your profile information will be erased. This action cannot be undone.',
            style: TextStyle(color: secondaryTextColor, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() => _isUpdating = true);

                try {
                  await _authService.deleteAccount();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully.'),
                      backgroundColor: Color(0xFF10293B),
                    ),
                  );

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                } on FirebaseAuthException catch (e) {
                  if (!mounted) return;
                  if (e.code == 'requires-recent-login') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('For security, please log out and log in again before deleting your account.'),
                        backgroundColor: Color(0xFF581818),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.message ?? 'Failed to delete account.'),
                        backgroundColor: const Color(0xFF581818),
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: const Color(0xFF581818),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isUpdating = false);
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFE45B5B), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final email = user?.email ?? 'No email';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _authService.streamUserProfile(),
          builder: (context, snapshot) {
            final docData = snapshot.data?.data();
            final displayName = docData?['displayName']?.toString().trim().isNotEmpty == true
                ? docData!['displayName']
                : (user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Smart Switch User');

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF193B57),
                          border: Border.all(color: primaryColor, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, size: 52, color: Color(0xFF91BAE2)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _showEditProfileDialog(displayName),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor,
                            ),
                            child: const Icon(Icons.edit, size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    email,
                    style: const TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),

                  if (_isUpdating) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      backgroundColor: borderColor,
                      color: primaryColor,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Settings Card
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _ProfileOption(
                          icon: Icons.person_outline,
                          title: 'Edit Display Name',
                          subtitle: displayName,
                          onTap: () => _showEditProfileDialog(displayName),
                        ),
                        const Divider(color: borderColor, height: 1),
                        _ProfileOption(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          subtitle: 'Send reset link to email',
                          onTap: () => _sendPasswordReset(email),
                        ),
                        const Divider(color: borderColor, height: 1),
                        _ProfileOption(
                          icon: Icons.delete_forever_outlined,
                          title: 'Delete Account',
                          subtitle: 'Permanently remove account and data',
                          isLogout: true,
                          onTap: _showDeleteAccountDialog,
                        ),
                        const Divider(color: borderColor, height: 1),
                        _ProfileOption(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of this device',
                          isLogout: true,
                          onTap: _showLogoutDialog,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Version
                  const Text(
                    'IoT Smart Switch • Production v1.0.0',
                    style: TextStyle(color: Color(0xFF4C5D6C), fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLogout;

  const _ProfileOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isLogout ? const Color(0xFFE45B5B) : const Color(0xFFE8EEF3);
    final Color iconColor = isLogout ? const Color(0xFFE45B5B) : const Color(0xFF5AA9FF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isLogout ? const Color(0xFF331B1B) : const Color(0xFF0B2133),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Color(0xFF8999A6), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isLogout ? Icons.chevron_right : Icons.chevron_right,
              color: const Color(0xFF5A7080),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}