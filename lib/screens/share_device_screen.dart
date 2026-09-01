import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class ShareDeviceScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<Map<String, dynamic>>? switches;

  const ShareDeviceScreen({
    super.key,
    required this.onBack,
    this.switches,
  });

  @override
  State<ShareDeviceScreen> createState() => _ShareDeviceScreenState();
}

class _ShareDeviceScreenState extends State<ShareDeviceScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  bool _viewOnly = false;
  bool _control = true;
  bool _isLoading = false;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    if (widget.switches != null && widget.switches!.isNotEmpty) {
      _selectedDeviceId = widget.switches!.first['deviceId']?.toString() ??
          widget.switches!.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentDevice {
    if (widget.switches == null || widget.switches!.isEmpty) return null;
    return widget.switches!.firstWhere(
          (s) =>
      (s['deviceId']?.toString() ?? s['id']?.toString()) == _selectedDeviceId,
      orElse: () => widget.switches!.first,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _shareDevice() async {
    final email = _emailController.text.trim();
    final device = _currentDevice;

    if (device == null || _selectedDeviceId == null) {
      _showSnackbar('Please select a device to share');
      return;
    }

    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnackbar('Please enter a valid email address');
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = device['isOwner'] == true || device['ownerId'] == currentUid;

    if (!isOwner) {
      _showSnackbar('Permission Denied: Only the device owner can share access.');
      return;
    }

    final role = _control ? 'editor' : 'viewer';

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.shareDeviceWithEmail(
        deviceId: _selectedDeviceId!,
        targetEmail: email,
        role: role,
      );

      if (!mounted) return;

      _emailController.clear();
      _showSnackbar('Device successfully shared with $email ($role)!');
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to share: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeUser(String targetUid, String email) async {
    if (_selectedDeviceId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Revoke Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to revoke access for $email?', style: const TextStyle(color: Color(0xFF91A1AF))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF91A1AF))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Revoke', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.removeSharedUser(
        deviceId: _selectedDeviceId!,
        targetUid: targetUid,
      );

      if (!mounted) return;
      _showSnackbar('Revoked access for $email');
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to remove user: $e');
      }
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = _currentDevice;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwner = device != null && (device['isOwner'] == true || device['ownerId'] == currentUid);

    List<Map<String, dynamic>> sharedUsersList = [];
    if (device != null && device['sharedUsers'] is List) {
      sharedUsersList = List<Map<String, dynamic>>.from(
        (device['sharedUsers'] as List).whereType<Map<String, dynamic>>(),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          24,
        ),
        children: [
          // --------------------------------
          // HEADER
          // --------------------------------
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Share Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // --------------------------------
          // SELECT DEVICE (IF MULTIPLE)
          // --------------------------------
          if (widget.switches != null && widget.switches!.isNotEmpty) ...[
            const Text(
              'Select Device',
              style: TextStyle(
                color: Color(0xFFD5DCE3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF10293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF294354)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDeviceId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF10293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9AA8B5)),
                  items: widget.switches!.map((s) {
                    final id = s['deviceId']?.toString() ?? s['id']?.toString() ?? '';
                    final name = s['name']?.toString() ?? 'Switch';
                    final room = s['room']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('$name ($room)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDeviceId = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          if (!isOwner) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2113),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF634D21)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFE5B558), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are a shared user. Only the device owner can manage sharing permissions.',
                      style: TextStyle(color: Color(0xFFE5B558), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // --------------------------------
          // EMAIL
          // --------------------------------
          const Text(
            'Enter user email to share',
            style: TextStyle(
              color: Color(0xFFD5DCE3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _emailController,
            enabled: isOwner && !_isLoading,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'friend@example.com',
              hintStyle: const TextStyle(
                color: Color(0xFF7E8C98),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFF10293B),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF294354),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF5AA9FF),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // --------------------------------
          // PERMISSIONS
          // --------------------------------
          const Text(
            'Select Permissions',
            style: TextStyle(
              color: Color(0xFFD5DCE3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 6),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Control (Editor: Switch ON/OFF, Timers & Schedules)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            value: _control,
            activeColor: const Color(0xFF2689E8),
            checkColor: Colors.white,
            onChanged: isOwner && !_isLoading
                ? (value) {
              setState(() {
                _control = value ?? false;
                if (_control) _viewOnly = false;
              });
            }
                : null,
          ),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'View Only (Viewer: Read state & history only)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            value: _viewOnly,
            activeColor: const Color(0xFF2689E8),
            checkColor: Colors.white,
            onChanged: isOwner && !_isLoading
                ? (value) {
              setState(() {
                _viewOnly = value ?? false;
                if (_viewOnly) _control = false;
              });
            }
                : null,
          ),

          const SizedBox(height: 12),

          // --------------------------------
          // SHARE BUTTON
          // --------------------------------
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isOwner && !_isLoading ? _shareDevice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2689E8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF263C4E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Share Device',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // --------------------------------
          // SHARED USERS
          // --------------------------------
          const Text(
            'Shared Users',
            style: TextStyle(
              color: Color(0xFFD5DCE3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF1C3447),
              ),
            ),
            child: sharedUsersList.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No users currently shared with this device.',
                  style: TextStyle(
                    color: Color(0xFF7E8C98),
                    fontSize: 13,
                  ),
                ),
              ),
            )
                : Column(
              children: List.generate(
                sharedUsersList.length,
                    (index) {
                  final user = sharedUsersList[index];
                  final userEmail = user['email']?.toString() ?? 'User';
                  final userUid = user['uid']?.toString() ?? '';
                  final roleStr = user['role']?.toString() == 'viewer' ? 'View Only' : 'Control';

                  return Column(
                    children: [
                      _sharedUserRow(
                        uid: userUid,
                        email: userEmail,
                        permission: roleStr,
                        isOwner: isOwner,
                      ),
                      if (index != sharedUsersList.length - 1)
                        const Divider(
                          height: 1,
                          color: Color(0xFF1C3447),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sharedUserRow({
    required String uid,
    required String email,
    required String permission,
    required bool isOwner,
  }) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF607382),
                ),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFFB7C3CD),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                email,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: permission == 'Control'
                    ? const Color(0xFF1C4232)
                    : const Color(0xFF353022),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                permission,
                style: TextStyle(
                  color: permission == 'Control'
                      ? const Color(0xFF5DD879)
                      : const Color(0xFFE5B558),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isOwner) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 20),
                onPressed: () => _removeUser(uid, email),
                tooltip: 'Revoke Access',
              ),
            ],
          ],
        ),
      ),
    );
  }
}