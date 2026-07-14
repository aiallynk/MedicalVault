import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/timezone_provider.dart';
import '../data/family_care_api.dart';
import '../data/models/patient_profile.dart';
import '../providers/family_dashboard_provider.dart';

class EditFamilyMemberScreen extends StatefulWidget {
  const EditFamilyMemberScreen({super.key, required this.access});
  final FamilyProfileAccess access;

  @override
  State<EditFamilyMemberScreen> createState() => _EditFamilyMemberScreenState();
}

class _EditFamilyMemberScreenState extends State<EditFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _fieldErrors = {};
  late final TextEditingController _name;
  late final TextEditingController _relationship;
  late final TextEditingController _dateOfBirth;
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  late final TextEditingController _language;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyRelationship;
  late final TextEditingController _emergencyPhone;
  late String _gender;
  late String _bloodGroup;
  late String _timezone;
  bool _saving = false;

  PatientProfile get _profile => widget.access.profile;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _profile.displayName);
    _relationship = TextEditingController(text: widget.access.relationship);
    _dateOfBirth = TextEditingController(text: _profile.dateOfBirth ?? '');
    _allergies = TextEditingController(text: _profile.allergies.join(', '));
    _conditions = TextEditingController(text: _profile.conditions.join(', '));
    _language = TextEditingController(text: _profile.preferredLanguage);
    _emergencyName =
        TextEditingController(text: _profile.emergencyContact.name);
    _emergencyRelationship =
        TextEditingController(text: _profile.emergencyContact.relationship);
    _emergencyPhone =
        TextEditingController(text: _profile.emergencyContact.phone);
    _gender = _profile.gender ?? '';
    _bloodGroup = _profile.bloodGroup ?? '';
    _timezone = _profile.timezone;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _relationship,
      _dateOfBirth,
      _allergies,
      _conditions,
      _language,
      _emergencyName,
      _emergencyRelationship,
      _emergencyPhone
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  String? _required(String? value, String field) =>
      value == null || value.trim().isEmpty
          ? _fieldErrors[field] ?? 'This field is required.'
          : _fieldErrors[field];

  String? _dateError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return _fieldErrors['dateOfBirth'] ?? 'Use YYYY-MM-DD.';
    }
    final parsed = DateTime.tryParse(text);
    final parts = text.split('-').map(int.tryParse).toList(growable: false);
    if (parsed == null ||
        parts.length != 3 ||
        parsed.year != parts[0] ||
        parsed.month != parts[1] ||
        parsed.day != parts[2] ||
        parsed.isAfter(DateTime.now())) {
      return _fieldErrors['dateOfBirth'] ??
          'Enter a valid date that is not in the future.';
    }
    return _fieldErrors['dateOfBirth'];
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(_fieldErrors.clear);
    if (!_formKey.currentState!.validate()) return;
    final patch = <String, dynamic>{};
    void addIfChanged(String key, dynamic next, dynamic previous) {
      if (next != previous) patch[key] = next;
    }

    addIfChanged('displayName', _name.text.trim(), _profile.displayName);
    if (widget.access.role == 'owner') {
      addIfChanged('relationship', _relationship.text.trim(),
          widget.access.relationship);
    }
    addIfChanged(
        'dateOfBirth', _dateOfBirth.text.trim(), _profile.dateOfBirth ?? '');
    addIfChanged('gender', _gender.isEmpty ? null : _gender, _profile.gender);
    addIfChanged('bloodGroup', _bloodGroup.isEmpty ? null : _bloodGroup,
        _profile.bloodGroup);
    addIfChanged('timezone', _timezone, _profile.timezone);
    addIfChanged(
        'preferredLanguage', _language.text.trim(), _profile.preferredLanguage);
    final allergies = _split(_allergies.text);
    final conditions = _split(_conditions.text);
    if (!listEquals(allergies, _profile.allergies) ||
        !listEquals(conditions, _profile.conditions)) {
      patch['medicalSummary'] = {
        'allergies': allergies,
        'conditions': conditions
      };
    }
    final emergency = <String, String>{
      'name': _emergencyName.text.trim(),
      'relationship': _emergencyRelationship.text.trim(),
      'phone': _emergencyPhone.text.trim(),
    };
    if (emergency['name'] != _profile.emergencyContact.name ||
        emergency['relationship'] != _profile.emergencyContact.relationship ||
        emergency['phone'] != _profile.emergencyContact.phone) {
      patch['emergencyContact'] = emergency;
    }
    if (patch.isEmpty) {
      Navigator.pop(context, widget.access);
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await context
          .read<FamilyDashboardProvider>()
          .updateProfile(_profile.id, patch);
      if (mounted) Navigator.pop(context, result);
    } on FamilyCareApiException catch (error) {
      if (!mounted) return;
      setState(() => _fieldErrors
        ..clear()
        ..addAll(error.fields));
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save changes. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit family member')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Full name', border: OutlineInputBorder()),
                    validator: (value) => _required(value, 'displayName')),
                const SizedBox(height: 16),
                if (widget.access.role == 'owner') ...[
                  TextFormField(
                      controller: _relationship,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Your relationship',
                          border: OutlineInputBorder()),
                      validator: (value) => _required(value, 'relationship')),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                    controller: _dateOfBirth,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Date of birth',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder()),
                    validator: _dateError),
                const SizedBox(height: 16),
                _profileFields(),
                const SizedBox(height: 24),
                Text('Health summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _allergies,
                    decoration: const InputDecoration(
                        labelText: 'Allergies',
                        hintText: 'Comma-separated',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _conditions,
                    decoration: const InputDecoration(
                        labelText: 'Medical conditions',
                        hintText: 'Comma-separated',
                        border: OutlineInputBorder())),
                const SizedBox(height: 24),
                Text('Emergency contact',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _emergencyName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Contact name',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _emergencyRelationship,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Contact relationship',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _emergencyPhone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: 'Contact phone',
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['emergencyContact'])),
                const SizedBox(height: 28),
                SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save changes'))),
              ],
            ),
          ),
        ),
      );

  Widget _profileFields() => Column(children: [
        DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(
                labelText: 'Gender',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['gender']),
            items: const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
              DropdownMenuItem(
                  value: 'prefer_not_to_say', child: Text('Prefer not to say'))
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _gender = value ?? '')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            initialValue: _bloodGroup,
            decoration: InputDecoration(
                labelText: 'Blood group',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['bloodGroup']),
            items: const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'A+', child: Text('A+')),
              DropdownMenuItem(value: 'A-', child: Text('A-')),
              DropdownMenuItem(value: 'B+', child: Text('B+')),
              DropdownMenuItem(value: 'B-', child: Text('B-')),
              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
              DropdownMenuItem(value: 'O+', child: Text('O+')),
              DropdownMenuItem(value: 'O-', child: Text('O-'))
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _bloodGroup = value ?? '')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            initialValue: _timezone,
            decoration: InputDecoration(
                labelText: 'Timezone',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['timezone']),
            items: TimezoneProvider.supportedTimeZones
                .map((zone) =>
                    DropdownMenuItem(value: zone.id, child: Text(zone.label)))
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (value) => setState(() => _timezone = value ?? _timezone)),
        const SizedBox(height: 16),
        TextFormField(
            controller: _language,
            decoration: InputDecoration(
                labelText: 'Preferred language',
                hintText: 'en or en-IN',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['preferredLanguage'])),
      ]);
}
