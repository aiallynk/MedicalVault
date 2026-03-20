import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpcomingAppointmentCard extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const UpcomingAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onCancel,
  });

  @override
  State<UpcomingAppointmentCard> createState() => _UpcomingAppointmentCardState();
}

class _UpcomingAppointmentCardState extends State<UpcomingAppointmentCard> {
  Timer? _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final apt = widget.appointment;
    final date = apt['appointmentDate'];
    final time = apt['appointmentTime'] ?? '00:00';
    if (date == null) {
      setState(() => _countdown = '');
      return;
    }
    DateTime aptDt;
    if (date is String) {
      aptDt = DateTime.parse(date);
    } else {
      aptDt = DateTime.fromMillisecondsSinceEpoch(date['\$date'] ?? 0);
    }
    final parts = time.toString().split(':');
    aptDt = DateTime(
      aptDt.year,
      aptDt.month,
      aptDt.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final now = DateTime.now();
    if (aptDt.isBefore(now)) {
      setState(() => _countdown = 'Started');
      return;
    }
    final diff = aptDt.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 24) {
      final d = diff.inDays;
      setState(() => _countdown = 'In $d days');
    } else if (h > 0) {
      setState(() => _countdown = 'Starts in ${h}h ${m}m');
    } else {
      setState(() => _countdown = 'Starts in ${m}m');
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.appointment;
    final doctor = apt['doctorId'];
    final doctorName = (doctor is Map ? doctor['name'] : apt['doctorName']) ?? 'Doctor';
    final specialization = (doctor is Map ? doctor['specialty'] : apt['doctorSpecialization']) ?? '';
    final hospital = apt['hospitalClinicName'] ?? (doctor is Map ? doctor['location'] : '') ?? '';
    final date = apt['appointmentDate'];
    final time = apt['appointmentTime'] ?? '';
    final type = apt['appointmentType'] ?? 'consultation';
    final status = apt['status'] ?? 'scheduled';
    final mode = apt['mode'] ?? 'in-person';
    final videoUrl = apt['videoCallUrl'] ?? '';

    String dateStr = '';
    if (date != null) {
      if (date is String) {
        dateStr = DateTime.tryParse(date)?.toLocal().toString().split(' ')[0] ?? date;
      } else if (date is Map && date['\$date'] != null) {
        dateStr = DateTime.fromMillisecondsSinceEpoch(date['\$date']).toLocal().toString().split(' ')[0];
      }
    }

    String typeLabel = type.toString();
    if (type == 'consultation') typeLabel = 'Consultation';
    else if (type == 'follow-up') typeLabel = 'Follow-up';
    else if (type == 'emergency') typeLabel = 'Emergency';
    else if (type == 'routine') typeLabel = 'Routine';
    else if (type == 'specialist') typeLabel = 'Specialist';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      (doctorName.toString().isNotEmpty ? doctorName.toString()[0] : 'D').toUpperCase(),
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. $doctorName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (specialization.toString().isNotEmpty)
                          Text(
                            specialization.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (status as String).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              if (hospital.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hospital.toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$dateStr at $time', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.medical_services, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(typeLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.videocam, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(mode == 'online' ? 'Online' : 'In-person', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              if (_countdown.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      _countdown,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (mode == 'online' && videoUrl.toString().isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(videoUrl.toString());
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text('Join Call'),
                    ),
                  TextButton.icon(
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Reschedule'),
                  ),
                  if (widget.onCancel != null)
                    TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
