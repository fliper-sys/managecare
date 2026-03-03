import 'package:flutter/material.dart';

class GuestCard extends StatelessWidget {
  final String guestName;
  final String room;
  final DateTime checkIn;
  final DateTime? checkOut;
  final VoidCallback onTap;

  const GuestCard({
    super.key,
    required this.guestName,
    required this.room,
    required this.checkIn,
    this.checkOut,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(guestName),
        subtitle: Text('Room $room'),
        trailing: Text(checkIn.toString().split(' ')[0]),
        onTap: onTap,
      ),
    );
  }
}

