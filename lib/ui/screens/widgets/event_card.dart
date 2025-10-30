import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (event.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    event.location!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (event.description != null) ...[
              const SizedBox(height: 8),
              Text(
                event.description!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
