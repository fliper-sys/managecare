import 'package:flutter/material.dart';

class ShiftTrackerWidget extends StatelessWidget {
  const ShiftTrackerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift Tracker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.login),
              title: Text('Clock In'),
              subtitle: Text('9:00 AM'),
            ),
            const ListTile(
              leading: Icon(Icons.access_time),
              title: Text('Time Worked'),
              subtitle: Text('6.5 hours'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Clock Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

