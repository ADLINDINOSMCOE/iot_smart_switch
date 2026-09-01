import 'package:flutter/material.dart';

class SwitchDetailScreen extends StatefulWidget {
  final String name;
  final String room;
  final bool isOn;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final VoidCallback onBack;
  final bool canControl;
  final String role;

  const SwitchDetailScreen({
    super.key,
    required this.name,
    required this.room,
    required this.isOn,
    required this.icon,
    required this.onChanged,
    required this.onBack,
    this.canControl = true,
    this.role = 'Owner',
  });

  @override
  State<SwitchDetailScreen> createState() => _SwitchDetailScreenState();
}

class _SwitchDetailScreenState extends State<SwitchDetailScreen> {
  late bool isOn;

  @override
  void initState() {
    super.initState();
    isOn = widget.isOn;
  }

  @override
  void didUpdateWidget(covariant SwitchDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOn != widget.isOn) {
      setState(() {
        isOn = widget.isOn;
      });
    }
  }

  void _toggleSwitch() {
    if (!widget.canControl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('View-only access. You cannot toggle this relay.'),
          backgroundColor: Color(0xFF10293B),
        ),
      );
      return;
    }

    setState(() {
      isOn = !isOn;
    });

    widget.onChanged(isOn);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24,
        ),
        child: Column(
          children: [
            // --------------------------------
            // BACK BUTTON + SWITCH INFO + ROLE
            // --------------------------------
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.room,
                        style: const TextStyle(
                          color: Color(0xFF91A1AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.canControl
                        ? const Color(0xFF1C4232)
                        : const Color(0xFF353022),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.role,
                    style: TextStyle(
                      color: widget.canControl
                          ? const Color(0xFF5DD879)
                          : const Color(0xFFE5B558),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (!widget.canControl) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF282315),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF59451C)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: Color(0xFFE5B558), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have View-Only access to this device.',
                        style: TextStyle(color: Color(0xFFE5B558), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // --------------------------------
            // POWER BUTTON
            // --------------------------------
            GestureDetector(
              onTap: _toggleSwitch,
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 250,
                ),
                width: 174,
                height: 174,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF132B3C),
                  border: Border.all(
                    color: isOn
                        ? const Color(0xFF52D66C)
                        : const Color(0xFF344554),
                    width: 4,
                  ),
                  boxShadow: isOn
                      ? [
                    BoxShadow(
                      color: const Color(0xFF45B85D).withValues(alpha: 0.20),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                      : [],
                ),
                child: Center(
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF081726),
                      border: Border.all(
                        color: isOn
                            ? const Color(0xFF52D66C)
                            : const Color(0xFF344554),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 62,
                      color: isOn
                          ? Colors.white
                          : const Color(0xFF8A99A8),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------
            // STATUS
            // --------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: isOn
                        ? const Color(0xFF5DD879)
                        : const Color(0xFF8A99A8),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? const Color(0xFF5DD879)
                        : const Color(0xFF7E8C98),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF91A1AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // --------------------------------
            // POWER STATISTICS
            // --------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2234),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1C3447),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Power Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF294354),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF91A1AF),
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _statItem(
                          title: 'Runtime',
                          value: '2h 45m',
                        ),
                      ),
                      Expanded(
                        child: _statItem(
                          title: 'Energy Used',
                          value: '1.25 kWh',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------
  // STAT ITEM
  // --------------------------------
  Widget _statItem({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF91A1AF),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}