import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../services/device_service.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import '../services/switch_service.dart';
import '../services/timer_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/home_switch_card.dart';
import '../widgets/set_timer_modal.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_profile_header.dart';
import 'schedules_screen.dart';
import 'settings_screen.dart';
import 'switch_detail_screen.dart';
import 'timer_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final SwitchService? switchService;
  final TimerService? timerService;
  final ScheduleService? scheduleService;
  final DeviceService? deviceService;
  final NotificationService? notificationService;
  final Stream<List<SwitchModel>>? switchesStream;
  final Stream<List<ScheduleModel>>? timersStream;
  final Stream<List<DeviceModel>>? devicesStream;

  final bool enableCountdownTicker;

  const HomeScreen({
    super.key,
    required this.user,
    required this.themeModeNotifier,
    this.switchService,
    this.timerService,
    this.scheduleService,
    this.deviceService,
    this.notificationService,
    this.switchesStream,
    this.timersStream,
    this.devicesStream,
    this.enableCountdownTicker = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SwitchService _switchService;
  late final TimerService _timerService;
  late final ScheduleService _scheduleService;
  late final DeviceService _deviceService;
  late final NotificationService _notificationService;

  // Selected room filter: null means "All Rooms"
  String? _selectedRoom;

  // Optimistic UI state map: switchId -> optimistic isOn value
  final Map<String, bool> _optimisticOverrides = {};

  // In-flight pending Firestore writes
  final Set<String> _pendingSwitchIds = {};

  bool _isSeeding = false;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _switchService = widget.switchService ?? SwitchService.instance;
    _timerService = widget.timerService ?? TimerService.instance;
    _scheduleService = widget.scheduleService ?? ScheduleService.instance;
    _deviceService = widget.deviceService ?? DeviceService.instance;
    _notificationService =
        widget.notificationService ?? NotificationService.instance;

    _initNotifications();

    // Periodic 1-second ticker to update active countdown timers in real time
    if (widget.enableCountdownTicker) {
      _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _initNotifications() {
    _notificationService.requestPermission().then((granted) {
      if (granted) {
        _notificationService.registerDeviceToken(widget.user.uid);
      }
    });

    _notificationService.setupMessageHandlers(
      onNavigate: (target, data) {
        if (!mounted) return;
        if (target == 'schedules') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SchedulesScreen(
                scheduleService: _scheduleService,
                switchService: _switchService,
                userId: widget.user.uid,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  /// Toggles switch with optimistic UI update and error rollback
  Future<void> _handleSwitchToggle(SwitchModel switchModel, bool targetIsOn) async {
    final switchId = switchModel.id;
    final previousIsOn = switchModel.isOn;

    // Apply optimistic update immediately
    setState(() {
      _optimisticOverrides[switchId] = targetIsOn;
      _pendingSwitchIds.add(switchId);
    });

    try {
      developer.log(
        'Optimistic toggle: updating switch $switchId -> isOn: $targetIsOn',
        name: 'HomeScreen',
      );

      await _switchService.setSwitchState(
        switchId: switchId,
        isOn: targetIsOn,
      );

      developer.log(
        'Firestore write succeeded for $switchId.',
        name: 'HomeScreen',
      );

      if (mounted) {
        setState(() {
          _pendingSwitchIds.remove(switchId);
          _optimisticOverrides.remove(switchId);
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Firestore write failed for $switchId. Rolling back to $previousIsOn.',
        name: 'HomeScreen',
        error: e,
        stackTrace: stackTrace,
      );

      // Rollback optimistic state
      if (mounted) {
        setState(() {
          _optimisticOverrides.remove(switchId);
          _pendingSwitchIds.remove(switchId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update "${switchModel.name}". Reverted to ${previousIsOn ? "ON" : "OFF"}.',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSwitchToggle(switchModel, targetIsOn),
            ),
          ),
        );
      }
    }
  }

  Future<void> _seedSampleSwitches() async {
    setState(() => _isSeeding = true);
    try {
      await _switchService.seedSampleSwitches(userId: widget.user.uid, overwrite: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample switches seeded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
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

  Future<void> _handleCancelTimer(String timerId) async {
    try {
      await _timerService.cancelTimer(timerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer cancelled.'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel timer: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeModeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Smart Switch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Active Timers',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TimerScreen(
                    timerService: _timerService,
                    switchService: _switchService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
            tooltip: 'Schedules & Automations',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SchedulesScreen(
                    scheduleService: _scheduleService,
                    switchService: _switchService,
                    userId: widget.user.uid,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    themeModeNotifier: widget.themeModeNotifier,
                    notificationService: _notificationService,
                  ),
                ),
              );
            },
          ),
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
      body: StreamBuilder<List<SwitchModel>>(
        stream: widget.switchesStream ??
            _switchService.streamSwitches(userId: widget.user.uid),
        builder: (context, switchSnapshot) {
          // Loading State
          if (switchSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to Firestore switches stream...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Error State
          if (switchSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: CustomCard(
                  backgroundColor: const Color(0xFFEF4444).withAlpha(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFEF4444), size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load switches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${switchSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        onPressed: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final allSwitches = switchSnapshot.data ?? [];

          // Stream devices and active timers simultaneously
          return StreamBuilder<List<DeviceModel>>(
            stream: widget.devicesStream ?? _deviceService.streamDevices(),
            builder: (context, deviceSnapshot) {
              final devices = deviceSnapshot.data ?? [];
              final Map<String, DeviceModel> devicesMap = {
                for (var d in devices) d.deviceId: d
              };

              return StreamBuilder<List<ScheduleModel>>(
                stream: widget.timersStream ?? _timerService.streamActiveTimers(),
                builder: (context, timerSnapshot) {
                  final activeTimers = timerSnapshot.data ?? [];
                  final Map<String, ScheduleModel> timersMap = {};
                  for (final timer in activeTimers) {
                    if (timer.isPending) {
                      timersMap[timer.switchId] = timer;
                    }
                  }

                  return SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Authenticated User Profile & Logout Header
                            UserProfileHeader(user: widget.user),
                            const SizedBox(height: 16),

                            // Empty State
                            if (allSwitches.isEmpty) ...[
                              _buildEmptyState(),
                            ] else ...[
                              // Summary Metrics
                              _buildSummaryMetrics(
                                allSwitches,
                                activeTimers.length,
                                devices,
                              ),
                              const SizedBox(height: 16),

                              // Room Filter Chips
                              _buildRoomFilterChips(allSwitches),
                              const SizedBox(height: 16),

                              // Switches Grouped by Room
                              _buildGroupedSwitches(
                                allSwitches,
                                timersMap,
                                devicesMap,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryMetrics(
    List<SwitchModel> switches,
    int activeTimersCount,
    List<DeviceModel> devices,
  ) {
    final activeCount = switches.where((s) {
      return _optimisticOverrides[s.id] ?? s.isOn;
    }).length;
    final totalCount = switches.length;
    final roomsCount = switches.map((s) => s.room).toSet().length;
    final onlineDevicesCount = devices.where((d) => d.isOnline).length;

    return CustomCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            label: 'Active',
            value: '$activeCount',
            icon: Icons.power_rounded,
            color: activeCount > 0
                ? const Color(0xFF10B981)
                : Colors.grey,
          ),
          Container(height: 36, width: 1, color: Colors.grey.withAlpha(50)),
          _buildMetricItem(
            label: 'Total',
            value: '$totalCount',
            icon: Icons.toggle_on_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          Container(height: 36, width: 1, color: Colors.grey.withAlpha(50)),
          _buildMetricItem(
            label: 'Rooms',
            value: '$roomsCount',
            icon: Icons.meeting_room_rounded,
            color: const Color(0xFF0284C7),
          ),
          Container(height: 36, width: 1, color: Colors.grey.withAlpha(50)),
          _buildMetricItem(
            label: 'Devices',
            value: devices.isEmpty ? '-' : '$onlineDevicesCount/${devices.length}',
            icon: Icons.memory_rounded,
            color: onlineDevicesCount > 0
                ? const Color(0xFF10B981)
                : const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRoomFilterChips(List<SwitchModel> switches) {
    final uniqueRooms = switches.map((s) => s.room).toSet().toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All Rooms" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('All Rooms (${switches.length})'),
              selected: _selectedRoom == null,
              onSelected: (_) {
                setState(() => _selectedRoom = null);
              },
            ),
          ),
          // Individual room chips
          ...uniqueRooms.map((room) {
            final count = switches.where((s) => s.room == room).length;
            final isSelected = _selectedRoom == room;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$room ($count)'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedRoom = selected ? room : null;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGroupedSwitches(
    List<SwitchModel> allSwitches,
    Map<String, ScheduleModel> timersMap,
    Map<String, DeviceModel> devicesMap,
  ) {
    // Filter switches if room selected
    final filteredSwitches = _selectedRoom == null
        ? allSwitches
        : allSwitches.where((s) => s.room == _selectedRoom).toList();

    // Group filtered switches by room name
    final Map<String, List<SwitchModel>> roomGroups = {};
    for (final sw in filteredSwitches) {
      roomGroups.putIfAbsent(sw.room, () => []).add(sw);
    }

    final sortedRoomNames = roomGroups.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedRoomNames.map((roomName) {
        final switchesInRoom = roomGroups[roomName]!;
        final activeInRoom = switchesInRoom.where((s) {
          return _optimisticOverrides[s.id] ?? s.isOn;
        }).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.meeting_room_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  StatusBadge(
                    label: '$activeInRoom / ${switchesInRoom.length} Active',
                    type: activeInRoom > 0
                        ? StatusType.success
                        : StatusType.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Responsive grid / list of switches in this room
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  if (isWide) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.40,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: switchesInRoom.length,
                      itemBuilder: (context, idx) {
                        final sw = switchesInRoom[idx];
                        return _buildSwitchItem(
                          sw,
                          timersMap[sw.id],
                          devicesMap[sw.deviceId],
                        );
                      },
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: switchesInRoom.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final sw = switchesInRoom[idx];
                      return _buildSwitchItem(
                        sw,
                        timersMap[sw.id],
                        devicesMap[sw.deviceId],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSwitchItem(
    SwitchModel sw,
    ScheduleModel? activeTimer,
    DeviceModel? deviceModel,
  ) {
    final effectiveIsOn = _optimisticOverrides[sw.id] ?? sw.isOn;
    final isPending = _pendingSwitchIds.contains(sw.id);

    return HomeSwitchCard(
      switchModel: sw,
      effectiveIsOn: effectiveIsOn,
      isPending: isPending,
      activeTimer: activeTimer,
      deviceModel: deviceModel,
      onToggle: (targetVal) => _handleSwitchToggle(sw, targetVal),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SwitchDetailScreen(
              switchModel: sw,
              deviceModel: deviceModel,
              activeTimer: activeTimer,
              switchService: _switchService,
              timerService: _timerService,
              scheduleService: _scheduleService,
            ),
          ),
        );
      },
      onSetTimer: () => SetTimerModal.show(
        context,
        switchModel: sw,
        timerService: _timerService,
      ),
      onCancelTimer: (timerId) => _handleCancelTimer(timerId),
    );
  }

  Widget _buildEmptyState() {
    return CustomCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.power_off_rounded,
              size: 48,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Switches Configured Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your switches collection is currently empty. Tap below to seed sample switches (switch_1 through switch_4) to your Firestore database.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: _isSeeding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_isSeeding
                ? 'Seeding Switches...'
                : 'Seed Default Switches'),
            onPressed: _isSeeding ? null : _seedSampleSwitches,
          ),
        ],
      ),
    );
  }
}
