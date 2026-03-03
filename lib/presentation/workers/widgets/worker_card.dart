import 'package:flutter/material.dart';
import '../../../widgets/profile_avatar.dart';

class WorkerCard extends StatelessWidget {
  final String name;
  final String role;
  final String status;
  final String? email;
  final String? photoUrl;
  final VoidCallback onTap;

  const WorkerCard({
    super.key,
    required this.name,
    required this.role,
    required this.status,
    required this.onTap,
    this.email,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isOnDuty = status == 'On Duty';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: ProfileAvatar(
          photoUrl: photoUrl,
          initials: name.isNotEmpty ? name[0] : 'U',
          backgroundColor: isOnDuty ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role),
            if (email != null)
              Text(
                email!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: isOnDuty ? Colors.green : Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

