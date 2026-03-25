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
import 'appointment_detail_screen.dart';
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
  late final List<DateTime> _dateOptions;
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _dateOptions = _buildDateOptions();
    _selectedDate = _dateOptions.isNotEmpty ? _dateOptions.first : null;
    final times = _timesForSelectedDate();
    _selectedTime = times.isNotEmpty ? times.first : null;
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
    final rating = (widget.doctor['rating'] as num?)?.toDouble() ?? 4.6;
    final appointmentCount = widget.appointments.length;
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 3),
                                  AppText(
                                    rating.toStringAsFixed(1),
                                    variant: AppTextVariant.caption,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
                              if (newTimes.isNotEmpty) {
                                _selectedTime = newTimes.first;
                              }
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
                    'Available Time Slots',
                    variant: AppTextVariant.subtitle,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Wrap(
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
                  CustomButton(
                    label: 'Book Appointment',
                    icon: Icons.calendar_month_rounded,
                    gradient: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    onPressed: _bookSelectedSlot,
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

  void _bookSelectedSlot() {
    final match = _findMatchingAppointment();
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No exact slot found in your records. Please pick another date/time.',
          ),
        ),
      );
      return;
    }

    final id = match['_id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment details are not available.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointmentId: id),
      ),
    );
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

  Map<String, dynamic>? _findMatchingAppointment() {
    if (_selectedDate == null || _selectedTime == null) return null;
    for (final apt in widget.appointments) {
      final date = _parseDate(apt['appointmentDate']);
      final time = apt['appointmentTime']?.toString();
      if (date == null || time == null) continue;
      if (_isSameDay(date, _selectedDate!) &&
          _normalizeTime(time) == _selectedTime) {
        return apt;
      }
    }
    return null;
  }

  List<DateTime> _buildDateOptions() {
    final dates = <DateTime>[];
    for (final apt in widget.appointments) {
      final parsed = _parseDate(apt['appointmentDate']);
      if (parsed != null && !dates.any((d) => _isSameDay(d, parsed))) {
        dates.add(parsed);
      }
    }
    dates.sort((a, b) => a.compareTo(b));

    if (dates.isNotEmpty) return dates.take(7).toList();

    final now = nowForContextTimeZone(context);
    return List.generate(7, (i) => now.add(Duration(days: i)));
  }

  List<String> _timesForSelectedDate() {
    if (_selectedDate == null) return _fallbackTimes();
    final times = <String>[];
    for (final apt in widget.appointments) {
      final date = _parseDate(apt['appointmentDate']);
      if (date == null || !_isSameDay(date, _selectedDate!)) continue;
      final raw = apt['appointmentTime']?.toString();
      if (raw == null || raw.isEmpty) continue;
      final normalized = _normalizeTime(raw);
      if (!times.contains(normalized)) times.add(normalized);
    }
    times.sort();
    return times.isEmpty ? _fallbackTimes() : times;
  }

  List<String> _fallbackTimes() => const ['09:00', '11:00', '13:30', '16:00'];

  DateTime? _parseDate(dynamic value) {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return convertToSelectedTimeZone(value, timezoneId);
  }

  String _normalizeTime(String raw) {
    final parts = raw.split(':');
    if (parts.isEmpty) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
