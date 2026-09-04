import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final NotificationService? notificationService;

  const SettingsScreen({
    super.key,
    required this.themeModeNotifier,
    this.notificationService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final NotificationService _notificationService;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget.notificationService ?? NotificationService.instance;
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await _notificationService.requestPermission();
    setState(() {
      _notificationsEnabled = granted;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Push notifications enabled.'
                : 'Push notification permission was denied.',
          ),
          backgroundColor:
              granted ? const Color(0xFF10B981) : AppTheme.errorColor,
        ),
      );
    }
  }

  void _showShareDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Device'),
        content: const Text(
          'To grant another family member or room member access, have them create an account with their email address. Shared multi-user device authorization is synchronized across Cloud Firestore.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'IoT Smart Switch',
      applicationVersion: '1.0.0+1',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.power_settings_new_rounded,
          color: AppTheme.primaryColor,
          size: 32,
        ),
      ),
      children: const [
        Text(
          'A reliable, cloud-synchronized IoT smart switch control application featuring Flutter, Firebase Authentication, Cloud Firestore, ESP32 microcontroller firmware, atomic timer/schedule execution, and FCM notifications.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Appearance & Theme Card
                  CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appearance',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: widget.themeModeNotifier,
                          builder: (context, currentMode, _) {
                            return Column(
                              children: [
                                RadioListTile<ThemeMode>(
                                  title: const Text('System Default'),
                                  value: ThemeMode.system,
                                  groupValue: currentMode,
                                  onChanged: (val) {
                                    if (val != null) {
                                      widget.themeModeNotifier.value = val;
                                    }
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Dark Mode (Deep Blue)'),
                                  value: ThemeMode.dark,
                                  groupValue: currentMode,
                                  onChanged: (val) {
                                    if (val != null) {
                                      widget.themeModeNotifier.value = val;
                                    }
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Light Mode'),
                                  value: ThemeMode.light,
                                  groupValue: currentMode,
                                  onChanged: (val) {
                                    if (val != null) {
                                      widget.themeModeNotifier.value = val;
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notifications Card
                  CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          title: const Text('Push Notifications (FCM)'),
                          subtitle: const Text(
                            'Receive alerts for completed timers, schedule executions, and device offline warnings.',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _notificationsEnabled,
                          onChanged: (_) => _requestNotificationPermissions(),
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Device Sharing & System Card
                  CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device & System',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: const Icon(Icons.share_outlined, color: AppTheme.primaryColor),
                          title: const Text('Share Device'),
                          subtitle: const Text('Manage multi-user family access', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showShareDeviceDialog,
                        ),
                        const Divider(height: 8),
                        ListTile(
                          leading: const Icon(Icons.cloud_done_outlined, color: Color(0xFF10B981)),
                          title: const Text('Cloud Connection'),
                          subtitle: const Text('Google Cloud Firestore (REST & Stream)', style: TextStyle(fontSize: 12)),
                          trailing: const StatusBadge(label: 'CONNECTED', type: StatusType.success),
                        ),
                        const Divider(height: 8),
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: Color(0xFF0284C7)),
                          title: const Text('About IoT Smart Switch'),
                          subtitle: const Text('Version 1.0.0+1', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showAboutDialog,
                        ),
                      ],
                    ),
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
