import 'package:flutter/material.dart';
import '../models/switch_model.dart';
import '../services/switch_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/switch_tile.dart';

class Phase3DatabaseScreen extends StatefulWidget {
  final SwitchService switchService;

  const Phase3DatabaseScreen({
    super.key,
    required this.switchService,
  });

  @override
  State<Phase3DatabaseScreen> createState() => _Phase3DatabaseScreenState();
}

class _Phase3DatabaseScreenState extends State<Phase3DatabaseScreen> {
  final Set<String> _updatingSwitchIds = {};
  bool _isSeeding = false;
  final List<String> _logs = [];

  void _addLog(String msg) {
    setState(() {
      final timeStr = DateTime.now().toIso8601String().substring(11, 19);
      _logs.insert(0, '[$timeStr] $msg');
    });
  }

  Future<void> _handleSeedSwitches({bool overwrite = false}) async {
    setState(() => _isSeeding = true);
    _addLog('Seeding sample switch documents (switch_1..switch_4)...');

    try {
      await widget.switchService.seedSampleSwitches(overwrite: overwrite);
      _addLog('Sample switches seeded successfully in Firestore.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample switches seeded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      _addLog('Seeding failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeding failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _handleToggle(SwitchModel switchModel, bool newValue) async {
    final switchId = switchModel.id;
    setState(() {
      _updatingSwitchIds.add(switchId);
    });
    _addLog('Updating switch $switchId: isOn -> $newValue');

    try {
      await widget.switchService.setSwitchState(
        switchId: switchId,
        isOn: newValue,
      );
      _addLog('Firestore write confirmed for $switchId.');
    } catch (e) {
      _addLog('Firestore write failed for $switchId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update switch $switchId: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingSwitchIds.remove(switchId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phase 3 Overview Card
        _buildHeaderCard(theme),
        const SizedBox(height: 16),

        // Schema Definition Card
        _buildSchemaCard(theme),
        const SizedBox(height: 16),

        // Stream of Switches from Firestore
        _buildSwitchesStream(theme),
        const SizedBox(height: 16),

        // Live Database Activity Logs
        _buildLogsCard(theme),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
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
                      color: const Color(0xFF0284C7).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Phase 3: Firestore Database',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const StatusBadge(
                label: 'Real-time Sync',
                type: StatusType.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Managing the authoritative switches collection. Reading and writing switch documents with active Firestore stream listeners.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isSeeding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_isSeeding
                      ? 'Seeding...'
                      : 'Seed Sample Switches (switch_1..4)'),
                  onPressed: _isSeeding ? null : () => _handleSeedSwitches(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.data_object_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Authoritative Schema (switches/{switch_id})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '{\n'
              '  "name": string,      // e.g. "Living Room Light"\n'
              '  "room": string,      // e.g. "Living Room"\n'
              '  "isOn": boolean,     // true | false\n'
              '  "deviceId": string   // e.g. "esp32_001"\n'
              '}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchesStream(ThemeData theme) {
    return StreamBuilder<List<SwitchModel>>(
      stream: widget.switchService.streamSwitches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CustomCard(
            backgroundColor: const Color(0xFFEF4444).withAlpha(20),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Firestore Stream Error: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomCard(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Subscribing to Firestore switches stream...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final switches = snapshot.data ?? [];

        if (switches.isEmpty) {
          return CustomCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No Switches Found in Firestore',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the button above to seed sample switches (switch_1 through switch_4).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Firestore Switches (${switches.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Re-seed / Reset',
                        style: TextStyle(fontSize: 12)),
                    onPressed: _isSeeding
                        ? null
                        : () => _handleSeedSwitches(overwrite: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: switches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sw = switches[index];
                return SwitchTile(
                  switchModel: sw,
                  isUpdating: _updatingSwitchIds.contains(sw.id),
                  onToggle: (newValue) => _handleToggle(sw, newValue),
                );
              },
            ),
          ],
        );
      },
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
                    'Database Sync Log',
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
                      'Listening to Firestore switch events...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
