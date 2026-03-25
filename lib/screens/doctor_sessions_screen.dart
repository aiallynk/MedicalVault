import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../core/theme/theme.dart';
import '../providers/timezone_provider.dart';
import '../utils/timezone_utils.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_card.dart';
import 'appointment_detail_screen.dart';

class DoctorSessionsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorSessionsScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorSessionsScreen> createState() => _DoctorSessionsScreenState();
}

class _DoctorSessionsScreenState extends State<DoctorSessionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final past = await ApiService.fetchPastAppointments();
      final filtered = past
          .whereType<Map<String, dynamic>>()
          .where((apt) => _matchesDoctor(apt))
          .toList()
        ..sort((a, b) {
          final ad = _parseDate(a['appointmentDate']);
          final bd = _parseDate(b['appointmentDate']);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

      if (!mounted) return;
      setState(() {
        _sessions = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _matchesDoctor(Map<String, dynamic> apt) {
    final doctor = apt['doctorId'];
    final doctorId =
        (doctor is Map ? doctor['_id'] : apt['doctorId'])?.toString() ?? '';
    final doctorName =
        (doctor is Map ? doctor['name'] : apt['doctorName'])?.toString() ?? '';

    if (widget.doctorId.trim().isNotEmpty && doctorId.isNotEmpty) {
      return doctorId == widget.doctorId;
    }

    return doctorName.trim().toLowerCase() == widget.doctorName.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(
          'Previous Sessions',
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 10),
          AppText(
            'Unable to load previous sessions',
            variant: AppTextVariant.subtitle,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AppText(
            _error!,
            variant: AppTextVariant.caption,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: const [
          Icon(Icons.history_toggle_off_rounded, size: 52),
          SizedBox(height: 10),
          AppText(
            'No previous sessions found for this doctor yet.',
            variant: AppTextVariant.body,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final apt = _sessions[index];
        final doctor = apt['doctorId'];
        final doctorName =
            (doctor is Map ? doctor['name'] : apt['doctorName'])?.toString() ??
                widget.doctorName;
        final specialization =
            (doctor is Map ? doctor['specialty'] : apt['doctorSpecialization'])
                    ?.toString() ??
                '';
        final hospital = (apt['hospitalClinicName'] ??
                    (doctor is Map ? doctor['location'] : ''))
                ?.toString() ??
            '';
        final status = apt['status']?.toString() ?? 'completed';
        final time = apt['appointmentTime']?.toString() ?? '';
        final notes = apt['doctorNotesShared']?.toString().trim() ?? '';
        final id = apt['_id']?.toString() ?? '';

        final dateLabel = formatDateForContext(
          context,
          apt['appointmentDate'],
          pattern: 'EEE, d MMM yyyy',
          fallback: 'Date unavailable',
        );

        return CustomCard(
          glass: true,
          radius: AppRadii.large,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Text(
                      doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Dr. $doctorName',
                          variant: AppTextVariant.body,
                          fontWeight: FontWeight.w700,
                        ),
                        if (specialization.trim().isNotEmpty)
                          AppText(
                            specialization,
                            variant: AppTextVariant.caption,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AppText(
                      status.toUpperCase(),
                      variant: AppTextVariant.caption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppText(
                '$dateLabel at $time',
                variant: AppTextVariant.caption,
                fontWeight: FontWeight.w600,
              ),
              if (hospital.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                AppText(
                  hospital,
                  variant: AppTextVariant.caption,
                ),
              ],
              const SizedBox(height: 10),
              AppText(
                _summaryLine(dateLabel, time, status, notes),
                variant: AppTextVariant.caption,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: id.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AppointmentDetailScreen(appointmentId: id),
                            ),
                          );
                        },
                  icon: const Icon(Icons.summarize_rounded),
                  label: const Text('View detailed summary'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _summaryLine(
    String dateLabel,
    String time,
    String status,
    String notes,
  ) {
    if (notes.isNotEmpty) {
      return 'Summary: $notes';
    }

    final timeText = time.trim().isNotEmpty ? ' at $time' : '';
    return 'Summary: Session on $dateLabel$timeText was marked as ${status.toLowerCase()}.';
  }

  DateTime? _parseDate(dynamic value) {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return convertToSelectedTimeZone(value, timezoneId);
  }
}
