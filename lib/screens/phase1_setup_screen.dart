import 'package:flutter/material.dart';
import '../models/sanity_check_result.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class Phase1SetupScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const Phase1SetupScreen({
    super.key,
    required this.themeModeNotifier,
  });

  @override
  State<Phase1SetupScreen> createState() => _Phase1SetupScreenState();
}

class _Phase1SetupScreenState extends State<Phase1SetupScreen> {
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
    _addLog('Triggering Firestore Sanity Check...');

    try {
      final result = await FirebaseService.instance.runFirestoreSanityCheck();
      setState(() {
        _sanityResult = result;
      });

      if (result.isSuccess) {
        _addLog('Sanity Check Passed: Document written and verified successfully.');
      } else {
        _addLog('Sanity Check Failed at step ${result.step}: ${result.details}');
      }
    } catch (e) {
      _addLog('Sanity Check Encountered Error: $e');
    } finally {
      setState(() {
        _isRunningSanityCheck = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeModeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Smart Switch Setup'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
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
                // Header Banner
                _buildHeaderBanner(context),
                const SizedBox(height: 16),

                // Architecture & Structure Overview
                _buildStructureCard(context),
                const SizedBox(height: 16),

                // Firestore Read/Write Sanity Check Card
                _buildSanityCheckCard(context),
                const SizedBox(height: 16),

                // Live Console Logs
                _buildLiveLogsCard(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return CustomCard(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.hub_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phase 1: Project Setup',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Flutter + Firebase + ESP32 Track',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const StatusBadge(
                label: 'Phase 1 Active',
                type: StatusType.info,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Core infrastructure initialized. Firebase plugins connected, clean folder architecture established, and Firestore sanity verification ready.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStructureCard(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_copy_outlined,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Architecture & Folder Layout',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCheckItem(
            'lib/main.dart',
            'App entrypoint, theme injection, Firebase initialization',
            true,
          ),
          _buildCheckItem(
            'lib/models/',
            'Typed data models for Firestore switches & schedules',
            true,
          ),
          _buildCheckItem(
            'lib/services/',
            'AuthService, SwitchService, FirebaseService with Streams',
            true,
          ),
          _buildCheckItem(
            'lib/screens/',
            'Login, Home, Timer, Schedule, Diagnostics screens',
            true,
          ),
          _buildCheckItem(
            'lib/widgets/',
            'Reusable UI components, switch cards, status chips',
            true,
          ),
          _buildCheckItem(
            'lib/theme/',
            'Light/Dark design system with Material 3 palette',
            true,
          ),
          _buildCheckItem(
            'firmware/',
            'ESP32 firmware track (C/C++ Arduino framework + GPIO relay)',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, String subtitle, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF10B981) : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: subtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSanityCheckCard(BuildContext context) {
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
                      size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Firestore Sanity Routine',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
          const Text(
            'Executes a live test against Cloud Firestore: creates a structured test payload, writes it to _sanity_checks, reads it back, asserts field integrity, and cleans up.',
            style: TextStyle(fontSize: 13.5, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 16),
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
                  ? 'Testing Firestore Read/Write...'
                  : 'Run Firestore Read/Write Sanity Check'),
              onPressed: _isRunningSanityCheck ? null : _executeSanityCheck,
            ),
          ),
          if (_sanityResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sanityResult!.isSuccess
                    ? const Color(0xFF10B981).withAlpha(20)
                    : const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sanityResult!.isSuccess
                      ? const Color(0xFF10B981).withAlpha(60)
                      : const Color(0xFFEF4444).withAlpha(60),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _sanityResult!.isSuccess
                            ? Icons.verified_rounded
                            : Icons.error_rounded,
                        size: 18,
                        color: _sanityResult!.isSuccess
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sanityResult!.isSuccess
                            ? 'Sanity Check Verified'
                            : 'Check Failed (${_sanityResult!.step})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sanityResult!.isSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sanityResult!.details,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (_sanityResult!.errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Error: ${_sanityResult!.errorMessage}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveLogsCard(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal_rounded, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Setup Activity Logs',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
          const SizedBox(height: 10),
          Container(
            height: 140,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(Theme.of(context).brightness == Brightness.dark ? 120 : 15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'No events logged yet. Tap "Run Firestore Read/Write Sanity Check" to test.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
