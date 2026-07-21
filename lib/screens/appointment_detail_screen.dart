import 'package:flutter/material.dart';
import 'package:hello/api_service.dart';
import 'package:hello/core/theme/theme.dart';
import 'package:hello/widgets/app_text.dart';
import 'package:hello/widgets/custom_button.dart';
import 'package:hello/widgets/custom_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/timezone_provider.dart';
import '../utils/timezone_utils.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;
  final VoidCallback? onUpdated;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.onUpdated,
  });

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Map<String, dynamic>? _appointment;
  Map<String, dynamic>? _aiSummary;
  bool _loading = true;
  bool _loadingAI = false;

  List<DateTime> _dateOptions = [];
  List<String> _timeOptions = [];
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apt = await ApiService.fetchAppointmentDetail(widget.appointmentId);
    if (!mounted) return;

    final status = apt?['status']?.toString() ?? '';
    _initSchedule(apt ?? <String, dynamic>{});

    setState(() {
      _appointment = apt;
      _loading = false;
    });

    if (status == 'completed') {
      _loadAISummary();
    }
  }

  Future<void> _loadAISummary() async {
    setState(() => _loadingAI = true);
    final summary =
        await ApiService.getAppointmentAISummary(widget.appointmentId);
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _loadingAI = false;
      });
    }
  }

  Future<void> _askAI() async {
    if (_appointment == null) return;
    setState(() => _loadingAI = true);

    final result =
        await ApiService.generateAppointmentAISummary(widget.appointmentId);
    if (!mounted) return;

    setState(() => _loadingAI = false);

    if (result != null && result['success'] == true) {
      setState(() {
        _aiSummary = {
          'summary': result['summary'],
          'visitExplanation': result['visitExplanation'],
          'suggestedFollowUpDays': result['suggestedFollowUpDays'],
        };
      });
      return;
    }

    final prompt = 'Can you explain what happened in my doctor visit on '
        '${_appointment!['appointmentDate']} with Dr. ${_appointment!['doctorName']}? '
        'Use simple language.';
    final askResult = await ApiService.askAI(prompt);

    if (mounted && askResult != null) {
      final reply = askResult['reply'] ??
          askResult['message'] ??
          'Unable to generate summary.';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Visit Summary'),
          content: SingleChildScrollView(child: Text(reply)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointment Details')),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    final apt = _appointment!;
    final doctor = apt['doctorId'];
    final doctorName =
        (doctor is Map ? doctor['name'] : apt['doctorName'])?.toString() ??
            'Doctor';
    final specialization =
        (doctor is Map ? doctor['specialty'] : apt['doctorSpecialization'])
                ?.toString() ??
            '';
    final hospital =
        (apt['hospitalClinicName'] ?? (doctor is Map ? doctor['location'] : ''))
                ?.toString() ??
            '';
    final date = apt['appointmentDate'];
    final time = apt['appointmentTime']?.toString() ?? '';
    final type = apt['appointmentType']?.toString() ?? 'consultation';
    final status = apt['status']?.toString() ?? '';
    final mode = apt['mode']?.toString() ?? 'in-person';
    final videoUrl = apt['videoCallUrl']?.toString() ?? '';
    final reason = apt['reason']?.toString() ?? '';
    final doctorNotesShared = apt['doctorNotesShared']?.toString() ?? '';
    final linkedDocs = apt['linkedDocuments'] as List<dynamic>? ?? [];

    final isUpcoming = ['scheduled', 'confirmed', 'pending'].contains(status);
    final canReschedule = ['scheduled', 'confirmed'].contains(status);
    final isCompleted = status == 'completed';
    final dateLabel = formatDateForContext(
      context,
      date,
      pattern: 'EEE, d MMM yyyy',
      fallback: 'Date unavailable',
    );

    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Doctor Details',
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          if (isUpcoming)
            IconButton(
              icon: const Icon(Icons.cancel_rounded),
              onPressed: _cancelAppointment,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorHeader(doctorName, specialization, hospital),
            const SizedBox(height: 16),
            CustomCard(
              glass: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(type.toUpperCase()),
                      _buildBadge(status.toUpperCase()),
                      _buildBadge(mode == 'online' ? 'ONLINE' : 'IN-PERSON'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      AppText(
                        '$dateLabel at $time',
                        variant: AppTextVariant.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AppText(
                      'Reason: $reason',
                      variant: AppTextVariant.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (canReschedule) ...[
              const SizedBox(height: 16),
              _buildDateSelector(),
              const SizedBox(height: 14),
              _buildTimeSelector(),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Request Reschedule',
                icon: Icons.edit_calendar_rounded,
                gradient: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                onPressed: _requestReschedule,
              ),
            ] else if (isUpcoming) ...[
              const SizedBox(height: 16),
              CustomCard(
                glass: true,
                child: const AppText(
                  'This request is waiting for the doctor to confirm it. You can still cancel it if your plans change.',
                  variant: AppTextVariant.caption,
                ),
              ),
            ],
            if (isUpcoming && mode == 'online' && videoUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(videoUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Join Call'),
                ),
              ),
            ],
            if (doctorNotesShared.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const AppText(
                'Doctor Notes',
                variant: AppTextVariant.subtitle,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              CustomCard(
                glass: true,
                child: AppText(doctorNotesShared.trim()),
              ),
            ],
            if (linkedDocs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const AppText(
                'Documents',
                variant: AppTextVariant.subtitle,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              ...linkedDocs.map((doc) {
                final d = doc as Map<String, dynamic>;
                final title = d['title'] ?? d['type'] ?? 'Document';
                final docType = d['type'] ?? d['category'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CustomCard(
                    glass: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          docType == 'Prescription'
                              ? Icons.medication_rounded
                              : Icons.description_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                title.toString(),
                                variant: AppTextVariant.body,
                                fontWeight: FontWeight.w700,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (docType.toString().isNotEmpty)
                                AppText(
                                  docType.toString(),
                                  variant: AppTextVariant.caption,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 20),
              const AppText(
                'AI Summary',
                variant: AppTextVariant.subtitle,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              if (_loadingAI)
                const Center(child: CircularProgressIndicator())
              else if (_aiSummary != null &&
                  ((_aiSummary!['summary'] != null &&
                          _aiSummary!['summary'].toString().isNotEmpty) ||
                      (_aiSummary!['visitExplanation'] != null &&
                          _aiSummary!['visitExplanation']
                              .toString()
                              .isNotEmpty)))
                CustomCard(
                  glass: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_aiSummary!['summary'] != null &&
                          _aiSummary!['summary'].toString().isNotEmpty)
                        AppText(_aiSummary!['summary'].toString()),
                      if (_aiSummary!['visitExplanation'] != null &&
                          _aiSummary!['visitExplanation']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AppText(_aiSummary!['visitExplanation'].toString()),
                      ],
                      if (_aiSummary!['suggestedFollowUpDays'] != null) ...[
                        const SizedBox(height: 10),
                        AppText(
                          'Suggested follow-up: in ${_aiSummary!['suggestedFollowUpDays']} days',
                          variant: AppTextVariant.caption,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _askAI,
                    icon: const Icon(Icons.psychology_rounded),
                    label: const Text('Ask AI about this visit'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorHeader(
      String doctorName, String specialization, String hospital) {
    final theme = Theme.of(context);
    return CustomCard(
      radius: AppRadii.large,
      gradient: [
        theme.colorScheme.primary.withValues(alpha: 0.95),
        theme.colorScheme.secondary.withValues(alpha: 0.95),
      ],
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Dr. $doctorName',
                  variant: AppTextVariant.subtitle,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                if (specialization.trim().isNotEmpty)
                  AppText(
                    specialization,
                    variant: AppTextVariant.caption,
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                if (hospital.trim().isNotEmpty)
                  AppText(
                    hospital,
                    variant: AppTextVariant.caption,
                    color: Colors.white.withValues(alpha: 0.82),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: const [
                Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 3),
                AppText(
                  '4.8',
                  variant: AppTextVariant.caption,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppText(
        label,
        variant: AppTextVariant.caption,
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('EEE, d MMM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Select Date',
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final date = _dateOptions[index];
              final selected =
                  _selectedDate != null && _isSameDay(_selectedDate!, date);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: AppText(
                      dateFormat.format(date),
                      variant: AppTextVariant.caption,
                      color: selected ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _dateOptions.length,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Select Time',
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeOptions.map((slot) {
            final selected = _selectedTime == slot;
            return ChoiceChip(
              selected: selected,
              label: Text(slot),
              onSelected: (_) {
                setState(() {
                  _selectedTime = slot;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _initSchedule(Map<String, dynamic> apt) {
    final now = nowForContextTimeZone(context);
    final appointmentDate = _parseDate(apt['appointmentDate']);
    final baseDate = appointmentDate != null && appointmentDate.isAfter(now)
        ? appointmentDate
        : now;
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);

    _dateOptions = List.generate(
      14,
      (index) => DateTime(now.year, now.month, now.day + index),
    );

    final time = apt['appointmentTime']?.toString();
    final normalized =
        time != null && time.isNotEmpty ? _normalizeTime(time) : '10:00';
    _selectedTime = normalized;

    _timeOptions = _buildTimeOptions(normalized);
  }

  List<String> _buildTimeOptions(String selected) {
    final parts = selected.split(':');
    final hour = int.tryParse(parts[0]) ?? 10;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final slots = <String>{};
    for (final delta in [-90, -45, 0, 45, 90, 135]) {
      final total = (hour * 60 + minute + delta).clamp(0, 23 * 60 + 59);
      final h = (total ~/ 60).toInt();
      final m = (total % 60).toInt();
      slots.add(
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    }
    final sorted = slots.toList()..sort();
    return sorted;
  }

  String _normalizeTime(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(dynamic value) {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return convertToSelectedTimeZone(value, timezoneId);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _requestReschedule() async {
    final selectedDate = _selectedDate;
    final selectedTime = _selectedTime;
    if (selectedDate == null || selectedTime == null) return;

    final reason = await _collectRescheduleReason();
    if (reason == null || !mounted) return;

    final response = await ApiService.requestReschedule(widget.appointmentId, {
      'preferredDate':
          '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      'preferredTime': selectedTime,
      'reason': reason,
    });
    if (!mounted) return;
    final success = response?['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((response?['message'] ??
                (success
                    ? 'Reschedule request submitted.'
                    : 'Unable to request a reschedule.'))
            .toString()),
      ),
    );
    if (success) {
      widget.onUpdated?.call();
      await _load();
    }
  }

  Future<String?> _collectRescheduleReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request reschedule'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Tell the doctor why you need a new time',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _cancelAppointment() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final success = await ApiService.cancelAppointment(widget.appointmentId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
      widget.onUpdated?.call();
      Navigator.pop(context);
    }
  }
}
