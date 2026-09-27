import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/switch_device.dart';
import '../services/firestore_service.dart';
import '../services/network_service.dart';
import 'switch_detail_screen.dart';
import 'timer_screen.dart';
import 'schedule_screen.dart';
import 'share_device_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import '../services/schedule_executor_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String? _selectedSettingsPage;
  int? _selectedSwitchIndex;

  final FirestoreService _firestoreService = FirestoreService();
  final NetworkService _networkService = NetworkService();

  final ScheduleExecutorService _scheduleExecutor =
  ScheduleExecutorService();

  @override
  void initState() {
    super.initState();

    _initializeNetworkMonitoring();
    _scheduleExecutor.start();
  }

  @override
  void dispose() {
    _scheduleExecutor.stop();
    _networkService.dispose();
    super.dispose();
  }

  // =========================================================
  // NETWORK MONITORING
  // =========================================================

  void _initializeNetworkMonitoring() {
    _networkService.networkStatus.listen((isOnline) {
      if (mounted && !isOnline) {
        _showOfflineSnackbar();
      }
    });
  }

  void _showOfflineSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You are offline. Some features may be limited.',
        ),
        backgroundColor: Color(0xFF8B3E3E),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // =========================================================
  // ADD DEVICE
  // =========================================================

  void _showAddDeviceDialog() {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2234),
          title: const Text(
            'Add Smart Switch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText:
                    'Switch Name (e.g. Living Room Lamp)',
                    labelStyle: TextStyle(
                      color: Color(0xFF9AA8B5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Room (e.g. Living Room)',
                    labelStyle: TextStyle(
                      color: Color(0xFF9AA8B5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText:
                    'Device ID (optional / matches ESP32)',
                    labelStyle: TextStyle(
                      color: Color(0xFF9AA8B5),
                    ),
                    hintText: 'esp32_relay_01',
                    hintStyle: TextStyle(
                      color: Color(0xFF607080),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF9AA8B5),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final room = roomController.text.trim();
                final customId = idController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a switch name',
                      ),
                    ),
                  );
                  return;
                }

                if (customId.isNotEmpty &&
                    !FirestoreService.isValidDeviceId(
                      customId,
                    )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Invalid Device ID. Use 3-50 letters, numbers, hyphens or underscores.',
                      ),
                      backgroundColor: Color(0xFF10293B),
                    ),
                  );
                  return;
                }

                try {
                  await _firestoreService.addDevice(
                    name: name,
                    room: room.isEmpty
                        ? 'Main Room'
                        : room,
                    deviceId: customId.isNotEmpty
                        ? customId
                        : null,
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Smart Switch added successfully!',
                      ),
                      backgroundColor: Color(0xFF10293B),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to add switch: $e',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F80ED),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Switch'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // DELETE SWITCH
  // =========================================================

  Future<void> _deleteSwitch(
      String switchId,
      String switchName,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          title: const Text(
            'Delete Switch?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$switchName"?',
            style: const TextStyle(
              color: Color(0xFFB7C3CC),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF91A1AF),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB83C3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _firestoreService.deleteDevice(switchId);

      if (!mounted) return;

      // If the deleted switch was currently selected,
      // return to the Home page.
      if (_selectedSwitchIndex != null) {
        setState(() {
          _selectedSwitchIndex = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$switchName" deleted successfully',
          ),
          backgroundColor: const Color(0xFF10293B),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete switch: $e',
          ),
          backgroundColor: const Color(0xFF8B3E3E),
        ),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<SwitchDevice>>(
      stream: _firestoreService.streamUserDevices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF081726),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5AA9FF),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return PopScope(
            canPop: _currentIndex == 0 &&
                _selectedSwitchIndex == null &&
                _selectedSettingsPage == null,

            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;

              // Switch detail → Home
              if (_selectedSwitchIndex != null) {
                setState(() {
                  _selectedSwitchIndex = null;
                });
                return;
              }

              // Share page → Home
              if (_selectedSettingsPage != null) {
                setState(() {
                  _selectedSettingsPage = null;
                  _currentIndex = 0;
                });
                return;
              }

              // Timer / Schedule / Settings → Home
              if (_currentIndex != 0) {
                setState(() {
                  _currentIndex = 0;
                });
                return;
              }
            },

            child: Scaffold(
            backgroundColor: const Color(0xFF081726),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error loading switches: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          );
        }

        final devices = snapshot.data ?? [];

        final List<Map<String, dynamic>> switches =
        devices.map((d) {
          final role = d.getRoleForUser(currentUid);

          return {
            'id': d.id,
            'name': d.name,
            'room': d.room,
            'isOn': d.isOn,
            'deviceId': d.deviceId,
            'online': d.online,
            'ownerId': d.ownerId,
            'role': role.toDisplayString(),
            'canControl': d.canControl(currentUid),
            'isOwner': d.isOwner(currentUid),
            'sharedWith': d.sharedWith,
            'sharedUsers':
            d.sharedUsers.map((u) => u.toMap()).toList(),
            'timerActive': d.timerActive,
            'timerStartedAt': d.timerStartedAt,
            'timerDurationSeconds':
            d.timerDurationSeconds,
          };
        }).toList();

        final onlineCount = switches
            .where(
              (item) => item['online'] == true,
        )
            .length;

        if (_selectedSwitchIndex != null &&
            _selectedSwitchIndex! >= switches.length) {
          _selectedSwitchIndex = null;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF081726),

          // =================================================
          // APP BAR
          // =================================================

          appBar: _selectedSettingsPage == 'share'
              ? null
              : AppBar(
            backgroundColor:
            const Color(0xFF0D2234),
            elevation: 0,
            centerTitle: true,
            title: Text(
              _getAppBarTitle(switches),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        ) =>
                    const ProfileScreen(),
                    transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                        ) {
                      const begin =
                      Offset(-1.0, 0.0);
                      const end = Offset.zero;

                      final tween =
                      Tween<Offset>(
                        begin: begin,
                        end: end,
                      ).chain(
                        CurveTween(
                          curve:
                          Curves.easeInOut,
                        ),
                      );

                      return SlideTransition(
                        position:
                        animation.drive(
                          tween,
                        ),
                        child: child,
                      );
                    },
                    transitionDuration:
                    const Duration(
                      milliseconds: 300,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _showAddDeviceDialog,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF5AA9FF),
                ),
                tooltip: 'Add Switch',
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // =================================================
          // BODY
          // =================================================

          body: _selectedSettingsPage == 'share'
              ? Container(
            color: const Color(0xFF081726),
            child: ShareDeviceScreen(
              switches: switches,
              onBack: () {
                setState(() {
                  _selectedSettingsPage = null;
                });
              },
            ),
          )
              : _selectedSwitchIndex != null
              ? _buildSwitchDetail(switches)
              : _buildBottomPages(
            switches,
            onlineCount,
          ),

          // =================================================
          // BOTTOM NAVIGATION
          // =================================================

          bottomNavigationBar:
          _selectedSettingsPage == 'share'
              ? null
              : Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D2234),
              border: Border(
                top: BorderSide(
                  color: Color(0xFF1C3447),
                ),
              ),
            ),
            child: BottomNavigationBar(
              backgroundColor:
              const Color(0xFF0D2234),
              type:
              BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                  _selectedSwitchIndex =
                  null;
                  _selectedSettingsPage =
                  null;
                });
              },
              selectedItemColor:
              const Color(0xFF5AA9FF),
              unselectedItemColor:
              const Color(0xFF7E8C98),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home_outlined,
                  ),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.timer_outlined,
                  ),
                  label: 'Timer',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.calendar_today_outlined,
                  ),
                  label: 'Schedule',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.settings_outlined,
                  ),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // APP BAR TITLE
  // =========================================================

  String _getAppBarTitle(
      List<Map<String, dynamic>> switches,
      ) {
    if (_selectedSwitchIndex != null &&
        _selectedSwitchIndex! < switches.length) {
      return switches[_selectedSwitchIndex!]['name']
          .toString();
    }

    switch (_currentIndex) {
      case 0:
        return 'My Home';

      case 1:
        return 'Timer';

      case 2:
        return 'Schedule';

      case 3:
        return 'Settings';

      default:
        return 'My Home';
    }
  }

  // =========================================================
  // BOTTOM PAGES
  // =========================================================
  Widget _buildBottomPages(
      List<Map<String, dynamic>> switches,
      int onlineCount,
      ) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildHomePage(
          switches,
          onlineCount,
        ),

        TimerScreen(
          switches: switches,
          onBack: () {
            setState(() {
              _currentIndex = 0;
              _selectedSwitchIndex = null;
              _selectedSettingsPage = null;
            });
          },
        ),

        ScheduleScreen(
          switches: switches,
          onBack: () {
            setState(() {
              _currentIndex = 0;
              _selectedSwitchIndex = null;
              _selectedSettingsPage = null;
            });
          },
        ),

        SettingsScreen(
          onBack: () {
            setState(() {
              _currentIndex = 0;
              _selectedSwitchIndex = null;
              _selectedSettingsPage = null;
            });
          },
        ),
      ],
    );
  }

  // =========================================================
  // SWITCH DETAIL
  // =========================================================

  Widget _buildSwitchDetail(
      List<Map<String, dynamic>> switches,
      ) {
    final index = _selectedSwitchIndex!;

    if (index >= switches.length) {
      return const SizedBox();
    }

    final switchItem = switches[index];

    final bool canControl =
        switchItem['canControl'] == true;

    return SwitchDetailScreen(
      deviceId: switchItem['deviceId'].toString(),
      name: switchItem['name'].toString(),
      room: switchItem['room'].toString(),
      isOn: switchItem['isOn'] as bool,
      canControl: canControl,
      role: switchItem['role']?.toString() ??
          'Owner',
      icon: Icons.power_settings_new,
      onBack: () {
        setState(() {
          _selectedSwitchIndex = null;
        });
      },
      onChanged: (value) async {
        if (!canControl) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'View-only access. You cannot switch this relay.',
              ),
              backgroundColor: Color(0xFF10293B),
            ),
          );
          return;
        }

        await _updateSwitch(
          switchItem['deviceId'].toString(),
          value,
        );
      },
    );
  }

  // =========================================================
  // UPDATE SWITCH
  // =========================================================

  Future<void> _updateSwitch(
      String switchId,
      bool value,
      ) async {
    try {
      await _networkService.executeWithNetworkCheck(
            () => _firestoreService.updateSwitch(
          switchId,
          value,
        ),
      );
    } catch (e) {
      debugPrint(
        'UPDATE SWITCH ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _networkService.getNetworkErrorMessage(e),
          ),
          backgroundColor: const Color(0xFF8B3E3E),
        ),
      );
    }
  }

  // =========================================================
  // HOME PAGE
  // =========================================================

  Widget _buildHomePage(
      List<Map<String, dynamic>> switches,
      int onlineCount,
      ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ================================================
          // HEADER
          // ================================================

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Devices',
                style: TextStyle(
                  color: Color(0xFFD5DCE3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$onlineCount Online',
                style: const TextStyle(
                  color: Color(0xFF5DD879),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ================================================
          // DEVICES
          // ================================================

          Expanded(
            child: switches.isEmpty
                ? Center(
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.devices_other_outlined,
                    color: Color(0xFF607080),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No smart switches found',
                    style: TextStyle(
                      color: Color(0xFF91A1AF),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed:
                    _showAddDeviceDialog,
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Add First Switch',
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF2F80ED),
                      foregroundColor:
                      Colors.white,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              itemCount: switches.length,
              separatorBuilder:
                  (context, index) =>
              const SizedBox(
                height: 12,
              ),
              itemBuilder:
                  (context, index) {
                final switchItem =
                switches[index];

                final bool isOn =
                switchItem['isOn']
                as bool;

                final bool canControl =
                    switchItem['canControl'] ==
                        true;

                final String role =
                    switchItem['role']
                        ?.toString() ??
                        'Owner';

                // =================================================
                // LONG PRESS = DELETE
                // NORMAL TAP = OPEN DETAIL
                // =================================================

                return GestureDetector(
                  onLongPress: () {
                    if (switchItem['isOwner'] !=
                        true) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only the owner can delete this switch.',
                          ),
                          backgroundColor:
                          Color(0xFF8B3E3E),
                        ),
                      );
                      return;
                    }

                    _deleteSwitch(
                      switchItem['id']
                          .toString(),
                      switchItem['name']
                          ?.toString() ??
                          'Switch',
                    );
                  },
                  child: InkWell(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    // NORMAL TAP
                    onTap: () {
                      setState(() {
                        _selectedSwitchIndex =
                            index;
                      });
                    },

                    child: Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFF10293B,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          10,
                        ),
                      ),
                      child: Row(
                        children: [
                          // =========================================
                          // POWER ICON
                          // =========================================

                          Container(
                            width: 48,
                            height: 48,
                            decoration:
                            BoxDecoration(
                              color: isOn
                                  ? const Color(
                                0xFF1D5B35,
                              )
                                  : const Color(
                                0xFF1B2C39,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                8,
                              ),
                            ),
                            child: Icon(
                              Icons
                                  .power_settings_new,
                              color: isOn
                                  ? const Color(
                                0xFF65D881,
                              )
                                  : const Color(
                                0xFF8A99A8,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          // =========================================
                          // NAME + ROOM + ROLE
                          // =========================================

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child:
                                      Text(
                                        switchItem[
                                        'name']
                                            .toString(),
                                        style:
                                        const TextStyle(
                                          color:
                                          Colors.white,
                                          fontSize:
                                          16,
                                          fontWeight:
                                          FontWeight
                                              .w600,
                                        ),
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 8,
                                    ),

                                    _buildRoleBadge(
                                      role,
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  switchItem[
                                  'room']
                                      .toString(),
                                  style:
                                  const TextStyle(
                                    color:
                                    Color(
                                      0xFF91A1AF,
                                    ),
                                    fontSize:
                                    13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // =========================================
                          // SWITCH
                          // =========================================

                          Switch(
                            value: isOn,

                            thumbColor:
                            WidgetStateProperty
                                .resolveWith(
                                  (states) =>
                              Colors.white,
                            ),

                            trackColor:
                            WidgetStateProperty
                                .resolveWith(
                                  (states) {
                                if (states
                                    .contains(
                                  WidgetState
                                      .selected,
                                )) {
                                  return const Color(
                                    0xFF45B85D,
                                  );
                                }

                                return const Color(
                                  0xFF344554,
                                );
                              },
                            ),

                            onChanged:
                            canControl
                                ? (value) async {
                              await _updateSwitch(
                                switchItem[
                                'deviceId']
                                    .toString(),
                                value,
                              );
                            }
                                : (value) {
                              ScaffoldMessenger
                                  .of(
                                context,
                              )
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                  Text(
                                    'View-only permission: Relay control is disabled.',
                                  ),
                                  backgroundColor:
                                  Color(
                                    0xFF10293B,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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

  // =========================================================
  // ROLE BADGE
  // =========================================================

  Widget _buildRoleBadge(String role) {
    Color bg = const Color(0xFF193B59);
    Color fg = const Color(0xFF5AA9FF);

    if (role == 'Owner') {
      bg = const Color(0xFF1C4232);
      fg = const Color(0xFF5DD879);
    } else if (role == 'View Only') {
      bg = const Color(0xFF353022);
      fg = const Color(0xFFE5B558);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}