import 'package:flutter/material.dart';

import '../utils/timezone_utils.dart';

class PastAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  final VoidCallback onAskAI;

  const PastAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    required this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    final apt = appointment;
    final doctor = apt['doctorId'];
    final doctorName = (doctor is Map ? doctor['name'] : apt['doctorName']) ?? 'Doctor';
    final specialization = (doctor is Map ? doctor['specialty'] : apt['doctorSpecialization']) ?? '';
    final hospital = apt['hospitalClinicName'] ?? (doctor is Map ? doctor['location'] : '') ?? '';
    final date = apt['appointmentDate'];
    final time = apt['appointmentTime'] ?? '';
    final type = apt['appointmentType'] ?? 'consultation';
    final status = apt['status'] ?? 'completed';
    final mode = apt['mode'] ?? 'in-person';
    final doctorNotesShared = apt['doctorNotesShared'] ?? '';
    final linkedDocs = apt['linkedDocuments'] as List<dynamic>? ?? [];

    final dateStr = formatDateForContext(
      context,
      date,
      pattern: 'yyyy-MM-dd',
      fallback: '',
    );

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
        onTap: onTap,
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
                  Text(mode == 'online' ? 'Online' : 'In-person', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              if (doctorNotesShared.toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Doctor notes: ${doctorNotesShared.toString().trim()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (linkedDocs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: linkedDocs.map<Widget>((doc) {
                    final d = doc as Map<String, dynamic>;
                    final title = d['title'] ?? d['type'] ?? 'Document';
                    return Chip(
                      label: Text(title.toString(), style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onAskAI,
                    icon: const Icon(Icons.psychology, size: 18),
                    label: const Text('Ask AI about this visit'),
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
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'no-show':
        return Colors.orange;
      case 'missed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
