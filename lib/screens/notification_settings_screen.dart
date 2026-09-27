import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();

  bool _notificationsEnabled = true;
  bool _deviceStateNotifications = true;
  bool _scheduleNotifications = true;
  bool _energyAlerts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notificationsEnabled =
    await _notificationService.areNotificationsEnabled();

    final deviceState =
    await _notificationService.areDeviceStateNotificationsEnabled();

    final schedule =
    await _notificationService.areScheduleNotificationsEnabled();

    final energy =
    await _notificationService.areEnergyAlertsEnabled();

    if (mounted) {
      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _deviceStateNotifications = deviceState;
        _scheduleNotifications = schedule;
        _energyAlerts = energy;
        _isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // SWITCH TILE
  // ------------------------------------------------------------

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E405D),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onChanged == null
                        ? const Color(0xFF6F7D89)
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: onChanged == null
                        ? const Color(0xFF56636E)
                        : const Color(0xFF91A1AF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF5AA9FF),
            activeTrackColor: const Color(0xFF2F80ED),
            inactiveThumbColor: const Color(0xFF91A1AF),
            inactiveTrackColor: const Color(0xFF304454),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF5AA9FF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ------------------------------------------------------------
  // INFO CARD
  // ------------------------------------------------------------

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF193B59),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2F80ED),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF5AA9FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'About Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Notifications help you stay informed about your smart devices. You can customize which types of notifications you receive.',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081726),

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2234),
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------

      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF5AA9FF),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ------------------------------------------------
          // MASTER NOTIFICATION SWITCH
          // ------------------------------------------------

          _buildSwitchTile(
            title: 'Enable Notifications',
            subtitle:
            'Receive push notifications from the app',
            value: _notificationsEnabled,
            onChanged: (value) async {
              await _notificationService
                  .setNotificationsEnabled(value);

              if (mounted) {
                setState(() {
                  _notificationsEnabled = value;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------
          // NOTIFICATION TYPES
          // ------------------------------------------------

          _buildSectionTitle('Notification Types'),

          const SizedBox(height: 12),

          // Device State Notifications
          _buildSwitchTile(
            title: 'Device State Changes',
            subtitle:
            'Get notified when devices turn on/off',
            value: _deviceStateNotifications,
            onChanged: _notificationsEnabled
                ? (value) async {
              await _notificationService
                  .setDeviceStateNotificationsEnabled(
                value,
              );

              if (mounted) {
                setState(() {
                  _deviceStateNotifications = value;
                });
              }
            }
                : null,
          ),

          // Schedule Notifications
          _buildSwitchTile(
            title: 'Schedule Execution',
            subtitle:
            'Notifications when scheduled actions run',
            value: _scheduleNotifications,
            onChanged: _notificationsEnabled
                ? (value) async {
              await _notificationService
                  .setScheduleNotificationsEnabled(
                value,
              );

              if (mounted) {
                setState(() {
                  _scheduleNotifications = value;
                });
              }
            }
                : null,
          ),

          // Energy Alerts
          _buildSwitchTile(
            title: 'Energy Alerts',
            subtitle:
            'Alerts for unusual energy consumption',
            value: _energyAlerts,
            onChanged: _notificationsEnabled
                ? (value) async {
              await _notificationService
                  .setEnergyAlertsEnabled(value);

              if (mounted) {
                setState(() {
                  _energyAlerts = value;
                });
              }
            }
                : null,
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------
          // INFORMATION
          // ------------------------------------------------

          _buildInfoCard(),
        ],
      ),
    );
  }
}