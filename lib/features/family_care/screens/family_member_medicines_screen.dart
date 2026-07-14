import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/family_care_api.dart';
import '../data/models/family_care_extensions.dart';
import '../providers/family_dashboard_provider.dart';

class FamilyMemberMedicinesScreen extends StatefulWidget {
  const FamilyMemberMedicinesScreen(
      {super.key,
      required this.profileId,
      required this.canManage,
      required this.timezone,
      this.highlightedDoseEventId});
  final String profileId;
  final bool canManage;
  final String timezone;
  final String? highlightedDoseEventId;

  @override
  State<FamilyMemberMedicinesScreen> createState() =>
      _FamilyMemberMedicinesScreenState();
}

class _FamilyMemberMedicinesScreenState
    extends State<FamilyMemberMedicinesScreen> {
  List<FamilyMedication> _medications = const [];
  List<MedicationDoseEvent> _doses = const [];
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
        context
            .read<FamilyDashboardProvider>()
            .getMedications(widget.profileId),
        context.read<FamilyDashboardProvider>().getTodayDoses(widget.profileId),
      ]);
      if (mounted)
        setState(() {
          _medications = results[0] as List<FamilyMedication>;
          _doses = results[1] as List<MedicationDoseEvent>;
        });
    } on FamilyCareApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load medicines.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _MedicineForm(profileId: widget.profileId, timezone: widget.timezone),
    );
    if (created == true) _load();
  }

  Future<void> _doseAction(MedicationDoseEvent dose, String action) async {
    try {
      await context.read<FamilyDashboardProvider>().updateDose(
            widget.profileId,
            dose.id,
            action,
            snoozeMinutes: action == 'snooze' ? 15 : null,
          );
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
      return _MedicationError(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(children: [
            Expanded(
                child: Text("Today's doses",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (widget.canManage)
              IconButton(
                  tooltip: 'Add medicine',
                  onPressed: _add,
                  icon: const Icon(Icons.add_circle_outline)),
          ]),
          if (_doses.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No doses are scheduled for today.'))),
          for (final dose in _doses)
            Card(
              color: dose.id == widget.highlightedDoseEventId
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: Text(dose.medicationName ?? 'Medicine'),
                subtitle: Text(
                    '${dose.originalLocalTime} • ${dose.scheduleTimezone} • ${dose.status}'),
                trailing: widget.canManage &&
                        ['pending', 'due', 'snoozed', 'missed']
                            .contains(dose.status)
                    ? PopupMenuButton<String>(
                        onSelected: (action) => _doseAction(dose, action),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'taken', child: Text('Mark taken')),
                          PopupMenuItem(value: 'skipped', child: Text('Skip')),
                          PopupMenuItem(
                              value: 'snooze',
                              child: Text('Snooze 15 minutes')),
                        ],
                      )
                    : null,
              ),
            ),
          const SizedBox(height: 16),
          Text('All medicines',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (_medications.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Text('No profile-scoped medicines have been added.'))),
          for (final medicine in _medications)
            Card(
              child: ListTile(
                title: Text(
                    '${medicine.name}${medicine.strength.isEmpty ? '' : ' ${medicine.strength}'}'),
                subtitle: Text(
                    '${medicine.doseQuantity} ${medicine.doseUnit} • ${medicine.schedule?.localTimes.join(', ') ?? 'No scheduled time'} • ${medicine.schedule?.timezone ?? ''}'),
                trailing: Text(medicine.status),
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicineForm extends StatefulWidget {
  const _MedicineForm({required this.profileId, required this.timezone});
  final String profileId;
  final String timezone;
  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<_MedicineForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'tablet');
  final _times = TextEditingController(text: '08:00');
  final _startDate = TextEditingController(text: _today());
  final _endDate = TextEditingController();
  final _notes = TextEditingController();
  final _intervalHours = TextEditingController(text: '8');
  bool _saving = false;
  bool _noEndDate = true;
  String _frequency = 'once_daily';
  String _dosageForm = 'tablet';
  String _foodInstruction = 'not_specified';
  final Set<int> _weekdays = <int>{};

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _quantity.dispose();
    _unit.dispose();
    _times.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _notes.dispose();
    _intervalHours.dispose();
    super.dispose();
  }

  static String _today() {
    final today = DateTime.now();
    return '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  static bool _isDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  bool get _usesWeekdays =>
      _frequency == 'specific_weekdays' || _frequency == 'weekly';
  bool get _usesInterval => _frequency == 'every_x_hours';
  bool get _isAsNeeded => _frequency == 'as_needed';

  int? get _requiredTimeCount => switch (_frequency) {
        'once_daily' => 1,
        'twice_daily' => 2,
        'three_times_daily' => 3,
        _ => null,
      };

  List<String> _validTimes(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(item))
      .toList();

  void _changeFrequency(String value) {
    const defaults = <String, String>{
      'once_daily': '08:00',
      'twice_daily': '08:00, 20:00',
      'three_times_daily': '08:00, 14:00, 20:00',
    };
    setState(() {
      _frequency = value;
      if (defaults.containsKey(value)) _times.text = defaults[value]!;
    });
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    final times = _validTimes(_times.text);
    if (!_isAsNeeded && times.isEmpty) return;
    final requiredTimeCount = _requiredTimeCount;
    if (requiredTimeCount != null && times.length != requiredTimeCount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${_frequency.replaceAll('_', ' ')} requires exactly $requiredTimeCount local time${requiredTimeCount == 1 ? '' : 's'}.',
        ),
      ));
      return;
    }
    if (_usesWeekdays && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select one or more weekdays.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context
          .read<FamilyDashboardProvider>()
          .createMedication(widget.profileId, {
        'name': _name.text.trim(),
        'strength': _strength.text.trim(),
        'dosageForm': _dosageForm,
        'doseQuantity': num.tryParse(_quantity.text) ?? 0,
        'doseUnit': _unit.text.trim(),
        'foodInstruction': _foodInstruction,
        'startDate': _startDate.text.trim(),
        'endDate': _noEndDate ? null : _endDate.text.trim(),
        'noEndDate': _noEndDate,
        'notes': _notes.text.trim(),
        'schedule': {
          'scheduleType': _frequency,
          'localTimes': _isAsNeeded ? <String>[] : times,
          'weekdays': _weekdays.toList()..sort(),
          'intervalHours':
              _usesInterval ? int.tryParse(_intervalHours.text) : null,
          'timezone': widget.timezone,
          'fixedToProfileTimezone': true,
          'activeStartDate': _startDate.text.trim(),
          'activeEndDate': _noEndDate ? null : _endDate.text.trim(),
        },
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
            key: _key,
            child: ListView(children: [
              Text('Add medicine',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Medicine name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Medicine name is required.'
                      : null),
              const SizedBox(height: 12),
              TextField(
                  controller: _strength,
                  decoration: const InputDecoration(
                      labelText: 'Strength',
                      hintText: 'e.g. 500 mg',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dosageForm,
                decoration: const InputDecoration(
                    labelText: 'Dosage form', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                  DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
                  DropdownMenuItem(value: 'liquid', child: Text('Liquid')),
                  DropdownMenuItem(
                      value: 'injection', child: Text('Injection')),
                  DropdownMenuItem(value: 'topical', child: Text('Topical')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) =>
                    setState(() => _dosageForm = value ?? _dosageForm),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Dose quantity',
                            border: OutlineInputBorder()),
                        validator: (v) => (num.tryParse(v ?? '') ?? 0) > 0
                            ? null
                            : 'Enter a dose.')),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(
                            labelText: 'Unit', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Unit is required.'
                            : null)),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _foodInstruction,
                decoration: const InputDecoration(
                    labelText: 'Food instruction',
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'not_specified', child: Text('No instruction')),
                  DropdownMenuItem(
                      value: 'before_food', child: Text('Before food')),
                  DropdownMenuItem(
                      value: 'after_food', child: Text('After food')),
                  DropdownMenuItem(
                      value: 'with_food', child: Text('With food')),
                ],
                onChanged: (value) => setState(
                    () => _foodInstruction = value ?? _foodInstruction),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startDate,
                decoration: const InputDecoration(
                    labelText: 'Start date',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    _isDate((value ?? '').trim()) ? null : 'Use YYYY-MM-DD.',
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('No end date'),
                value: _noEndDate,
                onChanged: (value) => setState(() => _noEndDate = value),
              ),
              if (!_noEndDate) ...[
                TextFormField(
                  controller: _endDate,
                  decoration: const InputDecoration(
                      labelText: 'End date',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder()),
                  validator: (value) =>
                      _isDate((value ?? '').trim()) ? null : 'Use YYYY-MM-DD.',
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: const InputDecoration(
                    labelText: 'Frequency', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'once_daily', child: Text('Once daily')),
                  DropdownMenuItem(
                      value: 'twice_daily', child: Text('Twice daily')),
                  DropdownMenuItem(
                      value: 'three_times_daily',
                      child: Text('Three times daily')),
                  DropdownMenuItem(
                      value: 'specific_times', child: Text('Specific times')),
                  DropdownMenuItem(
                      value: 'specific_weekdays',
                      child: Text('Specific weekdays')),
                  DropdownMenuItem(
                      value: 'every_x_hours', child: Text('Every X hours')),
                  DropdownMenuItem(
                      value: 'alternate_days', child: Text('Alternate days')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(
                      value: 'as_needed', child: Text('As needed')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (value) {
                  if (value != null) _changeFrequency(value);
                },
              ),
              const SizedBox(height: 12),
              if (!_isAsNeeded)
                TextFormField(
                    controller: _times,
                    decoration: InputDecoration(
                        labelText: _requiredTimeCount == null
                            ? 'Exact local times'
                            : 'Exact local times ($_requiredTimeCount required)',
                        hintText: _requiredTimeCount == 1
                            ? '08:00'
                            : _requiredTimeCount == 2
                                ? '08:00, 20:00'
                                : _requiredTimeCount == 3
                                    ? '08:00, 14:00, 20:00'
                                    : '08:00, 20:00',
                        border: OutlineInputBorder()),
                    validator: (value) {
                      final times = _validTimes(value ?? '');
                      if (times.isEmpty) return 'Use one or more HH:mm times.';
                      final required = _requiredTimeCount;
                      if (required != null && times.length != required) {
                        return 'Enter exactly $required time${required == 1 ? '' : 's'} for this frequency.';
                      }
                      return null;
                    }),
              if (_usesInterval) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _intervalHours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Interval hours',
                      border: OutlineInputBorder()),
                  validator: (value) => (int.tryParse(value ?? '') ?? 0) >= 1
                      ? null
                      : 'Enter an interval of at least one hour.',
                ),
              ],
              if (_usesWeekdays) ...[
                const SizedBox(height: 12),
                Text('Weekdays', style: Theme.of(context).textTheme.titleSmall),
                _WeekdayPicker(
                    selected: _weekdays,
                    onChanged: (days) => setState(() {
                          _weekdays
                            ..clear()
                            ..addAll(days);
                        })),
              ],
              const SizedBox(height: 8),
              TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Notes', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              const Text(
                  'Times are stored in the family member’s IANA timezone. Travelling caregivers see the converted time. Prescription attachment remains optional and is selected from the member document vault when that document workflow is available.'),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Add medicine')),
            ]),
          ),
        ),
      );
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    const days = <(int, String)>[
      (0, 'Sun'),
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
    ];
    return Wrap(
      spacing: 8,
      children: days
          .map((day) => FilterChip(
                label: Text(day.$2),
                selected: selected.contains(day.$1),
                onSelected: (value) {
                  final next = Set<int>.from(selected);
                  if (value)
                    next.add(day.$1);
                  else
                    next.remove(day.$1);
                  onChanged(next);
                },
              ))
          .toList(),
    );
  }
}

class _MedicationError extends StatelessWidget {
  const _MedicationError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry'))
      ]));
}
