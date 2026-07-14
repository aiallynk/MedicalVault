import 'package:flutter/material.dart';

import '../data/family_care_api.dart';
import '../data/family_care_repository.dart';
import '../data/models/family_care_extensions.dart';

class FamilyMemberAppointmentsScreen extends StatefulWidget {
  const FamilyMemberAppointmentsScreen(
      {super.key, required this.profileId, required this.canManage});
  final String profileId;
  final bool canManage;
  @override
  State<FamilyMemberAppointmentsScreen> createState() =>
      _FamilyMemberAppointmentsScreenState();
}

class _FamilyMemberAppointmentsScreenState
    extends State<FamilyMemberAppointmentsScreen> {
  final _repository = FamilyCareRepository();
  List<FamilyAppointment> _appointments = const [];
  List<FamilyDoctor> _doctors = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.getAppointments(widget.profileId),
        _repository.getFamilyDoctors()
      ]);
      if (mounted)
        setState(() {
          _appointments = results[0] as List<FamilyAppointment>;
          _doctors = results[1] as List<FamilyDoctor>;
        });
    } on FamilyCareApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _AppointmentForm(profileId: widget.profileId, doctors: _doctors),
    );
    if (saved == true) _load();
  }

  Future<void> _cancel(FamilyAppointment appointment) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Cancel appointment?'),
              content: Text(
                  'Cancel the appointment with ${appointment.doctor.name}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel appointment'))
              ],
            ));
    if (confirmed != true) return;
    try {
      await _repository.cancelAppointment(widget.profileId, appointment.id);
      await _load();
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Retry'))
      ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(children: [
              Expanded(
                  child: Text('Appointments',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700))),
              if (widget.canManage)
                IconButton(
                    onPressed: _book,
                    tooltip: 'Book appointment',
                    icon: const Icon(Icons.add_circle_outline))
            ]),
            if (_doctors.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          Text('No active doctors are currently available.'))),
            if (_appointments.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No appointments for this family member.'))),
            for (final appointment in _appointments)
              Card(
                  child: ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: Text(appointment.doctor.name),
                subtitle: Text(
                    '${appointment.date} • ${appointment.time}\n${appointment.reason} • ${appointment.status}'),
                isThreeLine: true,
                trailing: widget.canManage &&
                        !['cancelled', 'completed', 'no-show']
                            .contains(appointment.status)
                    ? TextButton(
                        onPressed: () => _cancel(appointment),
                        child: const Text('Cancel'))
                    : null,
              )),
          ]),
    );
  }
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({required this.profileId, required this.doctors});
  final String profileId;
  final List<FamilyDoctor> doctors;
  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final _repository = FamilyCareRepository();
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  FamilyDoctor? _doctor;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  String _type = 'consultation';
  String _mode = 'in-person';
  bool _saving = false;
  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _dateText =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
  String get _timeText =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate() || _doctor == null) return;
    setState(() => _saving = true);
    try {
      await _repository.createAppointment(widget.profileId, {
        'doctorId': _doctor!.id,
        'appointmentDate': _dateText,
        'appointmentTime': _timeText,
        'reason': _reason.text.trim(),
        'notes': _notes.text.trim(),
        'appointmentType': _type,
        'mode': _mode
      });
      if (mounted) Navigator.pop(context, true);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
            key: _form,
            child: ListView(children: [
              Text('Book appointment',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<FamilyDoctor>(
                  value: _doctor,
                  // Doctor names/specializations can be much wider than a
                  // small phone's form field. Keep the selected value inside
                  // the available width instead of letting DropdownButton's
                  // internal horizontal RenderFlex overflow.
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Doctor', border: OutlineInputBorder()),
                  items: widget.doctors
                      .map((doctor) => DropdownMenuItem(
                          value: doctor,
                          child: Text(
                              '${doctor.name}${doctor.specialization.isEmpty ? '' : ' — ${doctor.specialization}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  selectedItemBuilder: (context) => widget.doctors
                      .map((doctor) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                              '${doctor.name}${doctor.specialization.isEmpty ? '' : ' — ${doctor.specialization}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => _doctor = value),
                  validator: (value) =>
                      value == null ? 'Choose a doctor.' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 730)));
                          if (value != null) setState(() => _date = value);
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_dateText))),
                const SizedBox(width: 12),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showTimePicker(
                              context: context, initialTime: _time);
                          if (value != null) setState(() => _time = value);
                        },
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_timeText)))
              ]),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Reason for visit',
                      border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Reason for visit is required.'
                      : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                      labelText: 'Appointment type',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'consultation', child: Text('Consultation')),
                    DropdownMenuItem(
                        value: 'follow-up', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'routine', child: Text('Routine')),
                    DropdownMenuItem(
                        value: 'specialist', child: Text('Specialist')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Emergency'))
                  ],
                  onChanged: (value) => setState(() => _type = value ?? _type)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  value: _mode,
                  decoration: const InputDecoration(
                      labelText: 'Visit mode', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'in-person', child: Text('In person')),
                    DropdownMenuItem(value: 'online', child: Text('Online'))
                  ],
                  onChanged: (value) => setState(() => _mode = value ?? _mode)),
              const SizedBox(height: 12),
              TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Requesting…' : 'Request appointment')),
            ])),
      ));
}
