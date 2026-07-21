import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../core/theme/theme.dart';
import '../providers/timezone_provider.dart';
import '../utils/timezone_utils.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_card.dart';
import 'doctor_sessions_screen.dart';
import 'direct_chat_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final List<Map<String, dynamic>> appointments;

  const DoctorDetailScreen({
    super.key,
    required this.doctor,
    required this.appointments,
  });

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  static const int _slotStartMinutes = 9 * 60;
  static const int _slotEndMinutes = 18 * 60;
  static const int _slotStepMinutes = 30;

  late final List<DateTime> _dateOptions;
  late List<Map<String, dynamic>> _knownAppointments;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _bookingAppointment = false;

  @override
  void initState() {
    super.initState();
    _knownAppointments = widget.appointments
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
    _dateOptions = _buildDateOptions();
    _selectedDate = _dateOptions.isNotEmpty ? _dateOptions.first : null;
    final times = _timesForSelectedDate();
    _selectedTime = times.isNotEmpty ? times.first : null;
    _loadDoctorUpcomingAppointments();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.doctor['name']?.toString() ?? 'Doctor';
    final resolvedSpecialization =
        _doctorField(['specialization', 'specialty']);
    final specialization = resolvedSpecialization.trim().isNotEmpty
        ? resolvedSpecialization
        : 'General Medicine';
    final imageUrl = _doctorField(
      [
        'imageUrl',
        'profilePictureUrl',
        'profilePicture',
        'avatarUrl',
        'avatar'
      ],
    );
    final resolvedImageUrl = ApiService.resolveMediaUrl(imageUrl) ?? '';
    final appointmentCount = widget.appointments.length;
    final experience = _doctorField(['yearsOfExperience', 'experience']);
    final bio = _doctorField(['bio']);
    final languages = widget.doctor['languages'] is List
        ? (widget.doctor['languages'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final doctorId = _doctorField(['_id', 'id', 'doctorId']);
    final doctorEmail = _doctorField(['email', 'doctorEmail']);
    final doctorPhone =
        _doctorField(['mobile', 'phone', 'doctorPhone', 'contactNumber']);
    final doctorChatUrl =
        _doctorField(['chatUrl', 'doctorChatUrl', 'chatDeepLink']);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, d MMM');
    final times = _timesForSelectedDate();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.26),
                              backgroundImage: resolvedImageUrl.isNotEmpty
                                  ? NetworkImage(resolvedImageUrl)
                                  : null,
                              child: resolvedImageUrl.isEmpty
                                  ? const Icon(
                                      Icons.medical_services_rounded,
                                      color: Colors.white,
                                      size: 44,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    'Dr. $name',
                                    variant: AppTextVariant.title,
                                    color: Colors.white,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  AppText(
                                    specialization,
                                    variant: AppTextVariant.caption,
                                    color: Colors.white.withValues(alpha: 0.86),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  CustomCard(
                    glass: true,
                    radius: AppRadii.large,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText(
                                'Doctor Profile',
                                variant: AppTextVariant.subtitle,
                                fontWeight: FontWeight.w700,
                              ),
                              const SizedBox(height: 6),
                              if (experience.trim().isNotEmpty)
                                AppText(
                                  '$experience years of experience',
                                  variant: AppTextVariant.caption,
                                )
                              else if (appointmentCount > 0)
                                AppText(
                                  '$appointmentCount appointment history entries',
                                  variant: AppTextVariant.caption,
                                ),
                              if (doctorEmail.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                AppText(
                                  doctorEmail.trim(),
                                  variant: AppTextVariant.caption,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  if (bio.trim().isNotEmpty || languages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CustomCard(
                      glass: true,
                      radius: AppRadii.large,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'About this doctor',
                            variant: AppTextVariant.subtitle,
                            fontWeight: FontWeight.w700,
                          ),
                          if (bio.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            AppText(bio, variant: AppTextVariant.caption),
                          ],
                          if (languages.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: languages
                                  .map((language) => Chip(
                                        label: Text(language),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(growable: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const AppText(
                    'Select Date',
                    variant: AppTextVariant.subtitle,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dateOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final date = _dateOptions[index];
                        final selected = _selectedDate != null &&
                            _isSameDay(date, _selectedDate!);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              final newTimes = _timesForSelectedDate();
                              _selectedTime =
                                  newTimes.isNotEmpty ? newTimes.first : null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.08),
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
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppText(
                    'Preferred Time',
                    variant: AppTextVariant.subtitle,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: times.isEmpty
                        ? Container(
                            key: ValueKey(_selectedDate.toString()),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const AppText(
                              'No preferred times are available for this date. Try another day.',
                              variant: AppTextVariant.caption,
                            ),
                          )
                        : Wrap(
                            key: ValueKey(_selectedDate.toString()),
                            spacing: 10,
                            runSpacing: 10,
                            children: times.map((time) {
                              final selected = _selectedTime == time;
                              return ChoiceChip(
                                selected: selected,
                                label: Text(time),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedTime = time;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                  const AppText(
                    'Your request is confirmed after the doctor reviews it.',
                    variant: AppTextVariant.caption,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    label: _bookingAppointment
                        ? 'Submitting...'
                        : 'Request Appointment',
                    icon: Icons.calendar_month_rounded,
                    gradient: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    onPressed: (_bookingAppointment || _selectedTime == null)
                        ? null
                        : _bookSelectedSlot,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDoctorChat(
                            doctorId: doctorId,
                            doctorName: name,
                            doctorAvatarUrl: resolvedImageUrl,
                            chatUrl: doctorChatUrl,
                            doctorEmail: doctorEmail,
                            doctorPhone: doctorPhone,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat with Doctor'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openPreviousSessions(
                            doctorId: doctorId,
                            doctorName: name,
                          ),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('View previous sessions'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookSelectedSlot() async {
    final selectedDate = _selectedDate;
    final selectedTime = _selectedTime;
    final doctorId = _doctorField(['_id', 'id', 'doctorId']);

    if (doctorId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor details are unavailable.')),
      );
      return;
    }
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time slot.')),
      );
      return;
    }

    final bookingInput = await _collectAppointmentInput();
    if (bookingInput == null || !mounted) return;

    setState(() {
      _bookingAppointment = true;
    });

    try {
      final response = await ApiService.requestAppointment(
        doctorId: doctorId,
        appointmentDate: selectedDate,
        appointmentTime: selectedTime,
        reason: bookingInput.reason,
        notes: bookingInput.notes,
        appointmentType: bookingInput.appointmentType,
        mode: bookingInput.mode,
        duration: bookingInput.duration,
      );

      if (!mounted) return;
      final success = response['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['message'] ??
                    (success
                        ? 'Appointment request submitted.'
                        : 'Failed to request appointment.'))
                .toString(),
          ),
          backgroundColor: success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );

      if (success) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _bookingAppointment = false;
        });
      }
    }
  }

  Future<_AppointmentInput?> _collectAppointmentInput() async {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String? localError;
    String appointmentType = 'consultation';
    String mode = 'in-person';
    int duration = 30;

    final result = await showDialog<_AppointmentInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Request Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: reasonController,
                      autofocus: true,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        hintText: 'Describe why you need this appointment',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: appointmentType,
                      decoration: const InputDecoration(
                        labelText: 'Appointment type',
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'consultation', child: Text('Consultation')),
                        DropdownMenuItem(
                            value: 'follow-up', child: Text('Follow-up')),
                        DropdownMenuItem(
                            value: 'routine', child: Text('Routine check-up')),
                        DropdownMenuItem(
                            value: 'specialist',
                            child: Text('Specialist visit')),
                      ],
                      onChanged: (value) => setDialogState(() {
                        appointmentType = value ?? 'consultation';
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration:
                          const InputDecoration(labelText: 'Visit mode'),
                      items: const [
                        DropdownMenuItem(
                            value: 'in-person', child: Text('In person')),
                        DropdownMenuItem(
                            value: 'online', child: Text('Online')),
                      ],
                      onChanged: (value) => setDialogState(() {
                        mode = value ?? 'in-person';
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: duration,
                      decoration: const InputDecoration(labelText: 'Duration'),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 minutes')),
                        DropdownMenuItem(value: 45, child: Text('45 minutes')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                      ],
                      onChanged: (value) => setDialogState(() {
                        duration = value ?? 30;
                      }),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    final notes = notesController.text.trim();
                    if (reason.isEmpty) {
                      setDialogState(() {
                        localError = 'Reason is required.';
                      });
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _AppointmentInput(
                        reason: reason,
                        notes: notes,
                        appointmentType: appointmentType,
                        mode: mode,
                        duration: duration,
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _openDoctorChat({
    required String doctorId,
    required String doctorName,
    required String doctorAvatarUrl,
    required String chatUrl,
    required String doctorEmail,
    required String doctorPhone,
  }) async {
    if (doctorId.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(
            counterpartId: doctorId.trim(),
            counterpartName: "Dr. $doctorName",
            counterpartRole: "doctor",
            counterpartAvatarUrl: doctorAvatarUrl,
          ),
        ),
      );
      return;
    }

    final message = await _promptDoctorMessage(doctorName);
    if (message == null || !mounted) return;

    if (doctorId.trim().isNotEmpty) {
      try {
        final response = await ApiService.sendMessageToDoctor(
          doctorId: doctorId.trim(),
          doctorName: doctorName,
          message: message.trim(),
        );
        if (!mounted) return;
        if (response?['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Message sent to Dr. $doctorName')),
          );
          return;
        }
      } catch (_) {
        // Fall back to external chat options below.
      }
    }

    await _openDoctorChatFallback(
      doctorName: doctorName,
      chatUrl: chatUrl,
      doctorEmail: doctorEmail,
      doctorPhone: doctorPhone,
      message: message,
    );
  }

  Future<String?> _promptDoctorMessage(String doctorName) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Message Dr. $doctorName'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Type your message...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dialogContext, text);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value?.trim();
  }

  Future<void> _openDoctorChatFallback({
    required String doctorName,
    required String chatUrl,
    required String doctorEmail,
    required String doctorPhone,
    required String message,
  }) async {
    Uri? target;

    if (chatUrl.trim().isNotEmpty) {
      target = Uri.tryParse(chatUrl.trim());
    } else if (doctorEmail.trim().isNotEmpty) {
      target = Uri(
        scheme: 'mailto',
        path: doctorEmail.trim(),
        queryParameters: {
          'subject': 'Consultation follow-up',
          'body': message,
        },
      );
    } else if (doctorPhone.trim().isNotEmpty) {
      target = Uri(
        scheme: 'sms',
        path: doctorPhone.trim(),
        queryParameters: {
          'body': 'Hello Dr. $doctorName, $message',
        },
      );
    }

    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doctor chat is not available right now. Please try from Requests after access is approved.',
          ),
        ),
      );
      return;
    }

    final canLaunch = await canLaunchUrl(target);
    if (!canLaunch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to open doctor chat at the moment.')),
      );
      return;
    }

    await launchUrl(target, mode: LaunchMode.externalApplication);
  }

  void _openPreviousSessions({
    required String doctorId,
    required String doctorName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSessionsScreen(
          doctorId: doctorId,
          doctorName: doctorName,
        ),
      ),
    );
  }

  String _doctorField(List<String> keys) {
    final sources = <Map<String, dynamic>>[
      widget.doctor,
      ...widget.appointments
          .map((apt) => apt['doctorId'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)),
    ];

    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return '';
  }

  List<DateTime> _buildDateOptions() {
    final now = nowForContextTimeZone(context);
    return List.generate(
      10,
      (index) => DateTime(now.year, now.month, now.day + index),
    );
  }

  List<String> _timesForSelectedDate() {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return const [];

    final blockedSlots = _blockedSlotsForDate(selectedDate);
    final now = nowForContextTimeZone(context);
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _isSameDay(selectedDate, today);

    final slots = <String>[];
    for (var minute = _slotStartMinutes;
        minute <= _slotEndMinutes - _slotStepMinutes;
        minute += _slotStepMinutes) {
      final hour = minute ~/ 60;
      final minutePart = minute % 60;
      final slot = '${hour.toString().padLeft(2, '0')}:'
          '${minutePart.toString().padLeft(2, '0')}';

      if (blockedSlots.contains(slot)) continue;

      if (isToday) {
        final slotDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          hour,
          minutePart,
        );
        if (!slotDateTime.isAfter(now.add(const Duration(minutes: 15)))) {
          continue;
        }
      }

      slots.add(slot);
    }
    return slots;
  }

  Set<String> _blockedSlotsForDate(DateTime date) {
    final blocked = <String>{};
    for (final apt in _knownAppointments) {
      final status = (apt['status'] ?? '').toString().trim().toLowerCase();
      if (!_blocksSlotStatus(status)) continue;

      final parsedDate = _parseDate(apt['appointmentDate']);
      if (parsedDate == null || !_isSameDay(parsedDate, date)) continue;

      final rawTime = apt['appointmentTime']?.toString().trim() ?? '';
      final startMinutes = _parseMinutesOfDay(rawTime);
      if (startMinutes == null) continue;

      final durationMinutes = _parseDurationMinutes(apt['duration']);
      final blockStart = (startMinutes ~/ _slotStepMinutes) * _slotStepMinutes;
      final blockEnd = startMinutes + durationMinutes;

      for (var minute = blockStart;
          minute < blockEnd;
          minute += _slotStepMinutes) {
        if (minute < _slotStartMinutes ||
            minute > _slotEndMinutes - _slotStepMinutes) {
          continue;
        }
        blocked.add(_slotLabelFromMinutes(minute));
      }
    }
    return blocked;
  }

  bool _blocksSlotStatus(String status) {
    if (status.isEmpty) return true;
    const activeStatuses = {
      'pending',
      'scheduled',
      'confirmed',
      'approved',
      'booked',
      'accepted',
      'ongoing',
      'active',
      'in_progress',
      'in-progress',
    };
    return activeStatuses.contains(status);
  }

  DateTime? _parseDate(dynamic value) {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return convertToSelectedTimeZone(value, timezoneId);
  }

  int _parseDurationMinutes(dynamic raw) {
    final parsed = int.tryParse((raw ?? '').toString().trim()) ?? 30;
    if (parsed <= 0) return 30;
    return parsed.clamp(_slotStepMinutes, 240).toInt();
  }

  int? _parseMinutesOfDay(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$',
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = match.group(3)?.toUpperCase();

    if (hour == null || minute == null) return null;
    if (minute < 0 || minute > 59) return null;

    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12;
      if (period == 'PM') hour += 12;
    } else if (hour < 0 || hour > 23) {
      return null;
    }

    return hour * 60 + minute;
  }

  String _slotLabelFromMinutes(int minute) {
    final hour = minute ~/ 60;
    final minutePart = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minutePart.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadDoctorUpcomingAppointments() async {
    final doctorId = _doctorField(['_id', 'id', 'doctorId']).trim();
    if (doctorId.isEmpty) return;

    try {
      final upcoming = await ApiService.fetchUpcomingAppointments();
      if (!mounted) return;

      final merged = <String, Map<String, dynamic>>{};
      void addIfRelevant(Map<String, dynamic> appointment) {
        if (!_matchesDoctor(appointment, doctorId)) return;
        final key = _appointmentKey(appointment);
        merged[key] = appointment;
      }

      for (final appointment in _knownAppointments) {
        addIfRelevant(appointment);
      }

      for (final raw in upcoming) {
        if (raw is! Map<String, dynamic>) continue;
        addIfRelevant(Map<String, dynamic>.from(raw));
      }

      final updated = merged.values.toList(growable: false);
      if (!mounted) return;
      setState(() {
        _knownAppointments = updated;
        final slots = _timesForSelectedDate();
        if (_selectedTime == null || !slots.contains(_selectedTime)) {
          _selectedTime = slots.isNotEmpty ? slots.first : null;
        }
      });
    } catch (_) {
      // Keep existing local doctor appointments when refresh fails.
    }
  }

  bool _matchesDoctor(Map<String, dynamic> appointment, String doctorId) {
    final doctor = appointment['doctorId'];
    final resolvedId = doctor is Map
        ? (doctor['_id'] ?? doctor['id'] ?? doctor['doctorId'])
            ?.toString()
            .trim()
        : doctor?.toString().trim();
    return resolvedId != null && resolvedId == doctorId;
  }

  String _appointmentKey(Map<String, dynamic> appointment) {
    final id = appointment['_id']?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
    final date = appointment['appointmentDate']?.toString().trim() ?? '';
    final time = appointment['appointmentTime']?.toString().trim() ?? '';
    final status = appointment['status']?.toString().trim() ?? '';
    return '$date|$time|$status';
  }
}

class _AppointmentInput {
  final String reason;
  final String notes;
  final String appointmentType;
  final String mode;
  final int duration;

  const _AppointmentInput({
    required this.reason,
    required this.notes,
    required this.appointmentType,
    required this.mode,
    required this.duration,
  });
}
