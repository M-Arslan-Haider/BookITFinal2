
import 'package:flutter/material.dart';
import 'package:order_booking_app/Databases/util.dart';
import 'package:flutter_svg/flutter_svg.dart';


/// Profile section widget.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BOOKIT",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text("ID: $user_id", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Name: $userName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Designation: $userDesignation',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/icons/3135715.png'), // Fallback PNG
            ),
          ],
        ),
      ),
    );
  }
}
