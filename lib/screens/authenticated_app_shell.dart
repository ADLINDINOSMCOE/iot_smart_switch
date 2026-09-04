import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/sanity_check_result.dart';
import '../services/firebase_service.dart';
import '../services/switch_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_profile_header.dart';
import 'phase3_database_screen.dart';

class AuthenticatedAppShell extends StatefulWidget {
  final User user;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const AuthenticatedAppShell({
    super.key,
    required this.user,
    required this.themeModeNotifier,
  });

  @override
  State<AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  bool _isRunningSanityCheck = false;
  SanityCheckResult? _sanityResult;
  final List<String> _logs = [];

  void _addLog(String msg) {
    setState(() {
      final timeStr = DateTime.now().toIso8601String().substring(11, 19);
      _logs.insert(0, '[$timeStr] $msg');
    });
  }

  Future<void> _executeSanityCheck() async {
    setState(() {
      _isRunningSanityCheck = true;
      _sanityResult = null;
    });
    _addLog('Triggering Authenticated Firestore Sanity Check...');

    try {
      final result = await FirebaseService.instance.runFirestoreSanityCheck();
      setState(() {
        _sanityResult = result;
      });

      if (result.isSuccess) {
        _addLog('Sanity Check Passed for UID: ${widget.user.uid}');
      } else {
        _addLog('Sanity Check Failed: ${result.details}');
      }
    } catch (e) {
      _addLog('Sanity Check Exception: $e');
    } finally {
      setState(() {
        _isRunningSanityCheck = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.themeModeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Smart Switch'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              widget.themeModeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Profile Header with Logout
                UserProfileHeader(user: widget.user),
                const SizedBox(height: 16),

                // Phase 3: Live Firestore Switches & Seeding
                Phase3DatabaseScreen(switchService: SwitchService.instance),
                const SizedBox(height: 16),

                // Phase 2 Verification Status Card
                _buildPhase2StatusCard(theme),
                const SizedBox(height: 16),

                // Auth Gate Security Card
                _buildAuthGateCard(theme),
                const SizedBox(height: 16),

                // Authenticated Firestore Verification
                _buildSanityCheckCard(theme),
                const SizedBox(height: 16),

                // Activity Logs
                _buildLogsCard(theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase2StatusCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Phase 2: Authentication',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const StatusBadge(
                label: 'Authenticated',
                type: StatusType.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Authentication is active and guarding all downstream resources. You are successfully signed in.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User UID', widget.user.uid),
                const SizedBox(height: 6),
                _buildDetailRow('Email', widget.user.email ?? 'N/A'),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Email Verified',
                  widget.user.emailVerified ? 'Yes' : 'No',
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Auth Provider',
                  widget.user.providerData
                      .map((p) => p.providerId)
                      .join(', '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthGateCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Hard Constraint: Auth Gate Enforcement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'The AuthGate widget strictly controls the application root. If a user logs out, all Firestore listeners and switch data are immediately unmounted and terminated.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSanityCheckCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Firestore Authenticated Verification',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              if (_sanityResult != null)
                StatusBadge(
                  label: _sanityResult!.isSuccess ? 'Passed' : 'Failed',
                  type: _sanityResult!.isSuccess
                      ? StatusType.success
                      : StatusType.error,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isRunningSanityCheck
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_isRunningSanityCheck
                  ? 'Verifying Firestore Access...'
                  : 'Run Authenticated Firestore Check'),
              onPressed: _isRunningSanityCheck ? null : _executeSanityCheck,
            ),
          ),
          if (_sanityResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _sanityResult!.isSuccess
                    ? const Color(0xFF10B981).withAlpha(20)
                    : const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _sanityResult!.details,
                style: TextStyle(
                  fontSize: 13,
                  color: _sanityResult!.isSuccess
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Activity Log',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              if (_logs.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 110,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(
                theme.brightness == Brightness.dark ? 120 : 15,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Ready for user operations.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => Text(
                      _logs[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
