import 'package:flutter/material.dart';
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color backgroundColor = Color(0xFF081726);
  static const Color groupColor = Color(0xFF10293B);
  static const Color borderColor = Color(0xFF1C3447);
  static const Color secondaryColor = Color(0xFF91A1AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: groupColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  color: secondaryColor,
                  size: 42,
                ),

                const SizedBox(height: 12),

                const Text(
                  'No Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'You are all caught up.',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}