import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> switches;
  final VoidCallback onBack;

  const TimerScreen({
    super.key,
    required this.switches,
    required this.onBack,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Timer? _clockTimer;

  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Rebuild the screen every second so the timer counts.
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() {
            _now = DateTime.now();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // DEVICE ID
  // =========================================================

  String _deviceId(
      Map<String, dynamic> device,
      ) {
    return device['deviceId']?.toString() ??
        device['id']?.toString() ??
        '';
  }

  // =========================================================
  // DATE CONVERTER
  // =========================================================

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // =========================================================
  // GET TIMER START TIME
  // =========================================================

  DateTime? _getStartedAt(
      Map<String, dynamic> device,
      ) {
    return _toDateTime(
      device['timerStartedAt'],
    );
  }

  // =========================================================
  // RUNNING SECONDS
  // =========================================================

  int _getRunningSeconds(
      Map<String, dynamic> device,
      ) {
    if (device['timerActive'] != true) {
      return 0;
    }

    final startedAt =
    _getStartedAt(device);

    if (startedAt == null) {
      return 0;
    }

    final seconds =
        _now.difference(startedAt).inSeconds;

    if (seconds < 0) {
      return 0;
    }

    return seconds;
  }

  // =========================================================
  // TOTAL SECONDS
  // =========================================================

  int _getSavedTotalSeconds(
      Map<String, dynamic> device,
      ) {
    final value =
    device['totalRuntimeSeconds'];

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  int _getTotalSeconds(
      Map<String, dynamic> device,
      ) {
    final saved =
    _getSavedTotalSeconds(device);

    if (device['timerActive'] == true) {
      return saved +
          _getRunningSeconds(device);
    }

    return saved;
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(
      int seconds,
      ) {
    if (seconds < 0) {
      seconds = 0;
    }

    final hours =
        seconds ~/ 3600;

    final minutes =
        (seconds % 3600) ~/ 60;

    final secs =
        seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // LIVE FIRESTORE CARD
  // =========================================================

  Widget _liveTimerCard(
      Map<String, dynamic> originalDevice,
      ) {
    final id =
    _deviceId(originalDevice);

    if (id.isEmpty) {
      return _buildTimerCard(
        originalDevice,
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('switches')
          .doc(id)
          .snapshots(),

      builder: (
          context,
          snapshot,
          ) {
        // Start with Home's data.
        Map<String, dynamic> device = {
          ...originalDevice,
        };

        // Replace with LIVE Firestore data.
        if (snapshot.hasData &&
            snapshot.data!.exists) {
          final firestoreData =
          snapshot.data!.data();

          if (firestoreData != null) {
            device = {
              ...originalDevice,
              ...firestoreData,
            };
          }
        }

        return _buildTimerCard(device);
      },
    );
  }

  // =========================================================
  // TIMER CARD
  // =========================================================

  Widget _buildTimerCard(
      Map<String, dynamic> device,
      ) {
    final id =
    _deviceId(device);

    final name =
        device['name']?.toString() ??
            'Switch';

    final room =
        device['room']?.toString() ??
            '';

    final isRunning =
        device['timerActive'] == true;

    final runningSeconds =
    _getRunningSeconds(device);

    final totalSeconds =
    _getTotalSeconds(device);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      padding: const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10293B),
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF286F91)
              : const Color(0xFF1E4056),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // POWER ICON
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isRunning
                  ? const Color(0xFF2E9149)
                  : const Color(0xFF20394A),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.power_settings_new,
              color: isRunning
                  ? Colors.white
                  : const Color(0xFF8FA2B1),
              size: 52,
            ),
          ),

          const SizedBox(width: 20),

          // CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // NAME + THREE DOTS
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),

                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert,
                        color:
                        Color(0xFF91A4B3),
                        size: 28,
                      ),
                      color:
                      const Color(0xFF173247),
                      onSelected: (value) {
                        if (value ==
                            'history') {
                          _showHistory(
                            id,
                            name,
                          );
                        }
                      },
                      itemBuilder: (_) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'history',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color:
                                  Colors.white,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  'History',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),

                if (room.isNotEmpty) ...[
                  const SizedBox(height: 2),

                  Text(
                    room,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      color:
                      Color(0xFF91A1AF),
                      fontSize: 17,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // RUNNING STATUS
                if (isRunning)
                  Row(
                    children: [
                      const Text(
                        'Running',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatTime(runningSeconds),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (!isRunning)
                  const Text(
                    'Stopped',
                    style: TextStyle(
                      color:
                      Color(0xFF91A1AF),
                      fontSize: 17,
                    ),
                  ),

                const SizedBox(height: 6),

                // TOTAL
                Row(
                  children: [
                    const Text(
                      'Total',
                      style:
                      TextStyle(
                        color:
                        Color(0xFF91A1AF),
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Text(
                      _formatTime(
                        totalSeconds,
                      ),
                      style:
                      TextStyle(
                        color: isRunning
                            ? const Color(
                          0xFF91A1AF,
                        )
                            : Colors.white,
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HISTORY
  // =========================================================

  void _showHistory(
      String deviceId,
      String deviceName,
      ) {
    if (deviceId.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      const Color(0xFF081726),
      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return _HistorySheet(
          firestore: _firestore,
          deviceId: deviceId,
          deviceName: deviceName,
        );
      },
    );
  }

  // =========================================================
  // PAGE
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFF081726),

      body: widget.switches.isEmpty
          ? const Center(
        child: Text(
          'No switches available',
          style: TextStyle(
            color: Color(0xFF91A1AF),
            fontSize: 16,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          7,
          16,
          30,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.only(
              bottom: 12,
            ),
            child: Text(
              'My Timers',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...widget.switches.map(
                (device) => _liveTimerCard(device),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// HISTORY SHEET
// =============================================================

class _HistorySheet
    extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String deviceId;
  final String deviceName;

  const _HistorySheet({
    required this.firestore,
    required this.deviceId,
    required this.deviceName,
  });

  DateTime? _toDateTime(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatTime(
      int seconds,
      ) {
    final h =
        seconds ~/ 3600;

    final m =
        (seconds % 3600) ~/ 60;

    final s =
        seconds % 60;

    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(
      DateTime? date,
      ) {
    if (date == null) {
      return '--';
    }

    final hour =
    date.hour % 12 == 0
        ? 12
        : date.hour % 12;

    final minute =
    date.minute
        .toString()
        .padLeft(2, '0');

    final period =
    date.hour >= 12
        ? 'PM'
        : 'AM';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '$hour:$minute $period';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return SafeArea(
      child: SizedBox(
        height:
        MediaQuery.of(context)
            .size
            .height *
            0.72,
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),

            Container(
              width: 45,
              height: 5,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFF607080,
                ),
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color:
                    Color(0xFF5AA9FF),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      '$deviceName History',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 21,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<
                      Map<String,
                          dynamic>>>(
                stream: firestore
                    .collection(
                  'switches',
                )
                    .doc(deviceId)
                    .collection(
                  'timerHistory',
                )
                    .orderBy(
                  'startedAt',
                  descending: true,
                )
                    .limit(50)
                    .snapshots(),

                builder:
                    (context, snapshot) {
                  if (snapshot
                      .hasError) {
                    return const Center(
                      child: Text(
                        'Unable to load history',
                        style:
                        TextStyle(
                          color:
                          Color(
                            0xFF91A1AF,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot
                      .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        Color(
                          0xFF5AA9FF,
                        ),
                      ),
                    );
                  }

                  final docs =
                      snapshot.data
                          ?.docs ??
                          [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No timer history',
                        style:
                        TextStyle(
                          color:
                          Color(
                            0xFF91A1AF,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView
                      .separated(
                    padding:
                    const EdgeInsets
                        .all(16),
                    itemCount:
                    docs.length,
                    separatorBuilder:
                        (_, __) =>
                    const Divider(
                      color:
                      Color(
                        0xFF1C3447,
                      ),
                    ),
                    itemBuilder:
                        (context,
                        index) {
                      final data =
                      docs[index]
                          .data();

                      int duration =
                      0;

                      final value =
                      data[
                      'durationSeconds'];

                      if (value
                      is num) {
                        duration =
                            value
                                .toInt();
                      }

                      final started =
                      _toDateTime(
                        data[
                        'startedAt'],
                      );

                      final stopped =
                      _toDateTime(
                        data[
                        'stoppedAt'],
                      );

                      final status =
                          data[
                          'status']
                              ?.toString() ??
                              '';

                      return Padding(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer,
                              color:
                              Color(
                                0xFF5AA9FF,
                              ),
                              size: 30,
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    _formatTime(
                                      duration,
                                    ),
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white,
                                      fontSize:
                                      17,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    'Started: ${_formatDate(started)}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Color(
                                        0xFF91A1AF,
                                      ),
                                      fontSize:
                                      12,
                                    ),
                                  ),

                                  if (stopped !=
                                      null)
                                    Text(
                                      'Stopped: ${_formatDate(stopped)}',
                                      style:
                                      const TextStyle(
                                        color:
                                        Color(
                                          0xFF91A1AF,
                                        ),
                                        fontSize:
                                        12,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (status ==
                                'active')
                              const Text(
                                'RUNNING',
                                style:
                                TextStyle(
                                  color:
                                  Color(
                                    0xFF54E66C,
                                  ),
                                  fontSize:
                                  12,
                                  fontWeight:
                                  FontWeight

                                      .bold,
                                ),
                              )
                            else
                              const Icon(
                                Icons
                                    .check_circle,
                                color:
                                Color(
                                  0xFF54E66C,
                                ),
                                size: 20,
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}