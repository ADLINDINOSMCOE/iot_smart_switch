import 'package:flutter/material.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081726),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            // TITLE
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Manage your app and device settings',
              style: TextStyle(
                color: Color(0xFF91A1AF),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 28),

            // DEVICE
            _buildSectionTitle('Device'),

            const SizedBox(height: 10),

            _buildSettingsCard(
              children: [
                _buildSettingsTile(
                  icon: Icons.share_outlined,
                  title: 'Share Device',
                  subtitle: 'Give access to another user',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Share Device',
                      content:
                      'Open a switch from the Home tab or tap the share icon to invite collaborators as Editors or Viewers.',
                    );
                  },
                ),

                _buildDivider(),

                _buildSettingsTile(
                  icon: Icons.devices_other_outlined,
                  title: 'Manage Devices',
                  subtitle: 'View and manage connected switches',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Manage Devices',
                      content:
                      'All your owned and shared smart switches are listed on the Home dashboard. You can add new switches using the + button.',
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // APP SETTINGS
            _buildSectionTitle('App Settings'),

            const SizedBox(height: 10),

            _buildSettingsCard(
              children: [
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Configure notification preferences',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),

                _buildDivider(),

                _buildSettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Appearance',
                  subtitle: 'Dark Mode (Always On)',
                  onTap: () {
                    _showAppearanceDialog(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SUPPORT
            _buildSectionTitle('Support & Security'),

            const SizedBox(height: 10),

            _buildSettingsCard(
              children: [
                _buildSettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Hardware Setup',
                  subtitle: 'ESP32 wiring & troubleshooting guide',
                  onTap: () {
                    _showHelpDialog(context);
                  },
                ),

                _buildDivider(),

                _buildSettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Security Architecture',
                  subtitle: 'TLS 1.3, RBAC, and zero-trust firmware',
                  onTap: () {
                    _showSecurityDialog(context);
                  },
                ),

                _buildDivider(),

                _buildSettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'IoT Smart Switch App v1.0.0',
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Center(
              child: Text(
                'IoT Smart Switch • Production v1.0.0',
                style: TextStyle(
                  color: Color(0xFF607080),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF91A1AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSettingsCard({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1C3447),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF10293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF5AA9FF),
                size: 23,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF91A1AF),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF91A1AF),
              size: 25,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 76),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFF1C3447),
      ),
    );
  }



  void _showAppearanceDialog(BuildContext context) {
    _showInfoDialog(
      context,
      title: 'Appearance',
      content: 'Dark mode is permanently enabled for high-contrast IoT switch management and reduced OLED/LCD power consumption.',
    );
  }

  void _showHelpDialog(BuildContext context) {
    _showInfoDialog(
      context,
      title: 'ESP32 & Hardware Setup Guide',
      content: '1. Hardware Wiring: Connect Relay IN pin to ESP32 GPIO 23, VCC to 5V/VIN, and GND to GND.\n\n'
          '2. Firmware Configuration: Copy `esp32/secrets.h.template` to `esp32/secrets.h` and provide your Wi-Fi SSID, Firebase Project ID, and Device ID.\n\n'
          '3. Pairing: Add the exact Device ID (e.g. esp32_relay_01) in the app to pair and control.',
    );
  }

  void _showSecurityDialog(BuildContext context) {
    _showInfoDialog(
      context,
      title: 'Security Architecture',
      content: '• Firebase Authentication: User UID authorization.\n'
          '• Firestore Security Rules: Strict Role-Based Access Control (Owner, Editor, Viewer).\n'
          '• Zero-Trust Microcontroller: No user passwords or service account keys on ESP32.\n'
          '• TLS 1.3 Certificate Pinning: Full Root CA validation (GTS Root R1 & GTS Root R4).\n'
          '• Anti-Replay: Server-trustworthy timestamps and exact Device ID validation.',
    );
  }

  void _showInfoDialog(BuildContext context, {required String title, required String content}) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Text(content, style: const TextStyle(color: Color(0xFFCBD6E0), fontSize: 13, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: Color(0xFF5AA9FF))),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('IoT Smart Switch', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Production-Ready Smart Switch Solution\n\n'
            '• Flutter Multi-Platform Client\n'
            '• Firebase Authentication & Cloud Firestore\n'
            '• ESP32 Hardware Relay Controller\n\n'
            'Version: 1.0.0+1\n'
            'Security Status: Hardened',
            style: TextStyle(color: Color(0xFF91A1AF), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: Color(0xFF5AA9FF))),
            ),
          ],
        );
      },
    );
  }
}