import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/timezone_provider.dart';
import '../data/family_care_api.dart';
import '../data/models/patient_profile.dart';
import '../data/models/family_care_extensions.dart';
import '../providers/family_dashboard_provider.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({
    super.key,
    this.managedProfileCount,
    this.managedProfileLimit,
  });

  final int? managedProfileCount;
  final int? managedProfileLimit;

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _language = TextEditingController(text: 'en');
  final _emergencyName = TextEditingController();
  final _emergencyRelationship = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _idempotencyKey = FamilyCareApi.newIdempotencyKey();
  final Map<String, String> _fieldErrors = {};
  bool _saving = false;
  bool _initializedTimeZone = false;
  String _timezone = TimezoneProvider.defaultTimeZone;
  String _gender = '';
  String _bloodGroup = '';
  String? _mode;

  bool get _managedProfileLimitReached =>
      widget.managedProfileCount != null &&
      widget.managedProfileLimit != null &&
      widget.managedProfileCount! >= widget.managedProfileLimit!;

  String get _managedProfileAvailability {
    if (widget.managedProfileCount == null ||
        widget.managedProfileLimit == null) {
      return 'Create a dependent profile without login credentials or a separate user account.';
    }
    return _managedProfileLimitReached
        ? 'You are using ${widget.managedProfileCount} of ${widget.managedProfileLimit} managed profiles.'
        : 'Create a dependent profile without login credentials or a separate user account. ${widget.managedProfileCount} of ${widget.managedProfileLimit} used.';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedTimeZone) {
      _timezone = context.read<TimezoneProvider>().timeZoneId;
      _initializedTimeZone = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _dateOfBirth.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _language.dispose();
    _emergencyName.dispose();
    _emergencyRelationship.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return _fieldErrors[field] ?? 'This field is required.';
    }
    return _fieldErrors[field];
  }

  String? _dateError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _fieldErrors['dateOfBirth'] ?? 'Date of birth is required.';
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
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

  List<String> _values(TextEditingController controller) => controller.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  Future<void> _save() async {
    if (_saving) return;
    setState(_fieldErrors.clear);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final emergency = <String, String>{
        'name': _emergencyName.text.trim(),
        'relationship': _emergencyRelationship.text.trim(),
        'phone': _emergencyPhone.text.trim(),
      };
      final result = await context
          .read<FamilyDashboardProvider>()
          .createManagedProfile(
            displayName: _name.text.trim(),
            relationship: _relationship.text.trim(),
            dateOfBirth: _dateOfBirth.text.trim(),
            timezone: _timezone,
            gender: _gender.isEmpty ? null : _gender,
            bloodGroup: _bloodGroup.isEmpty ? null : _bloodGroup,
            allergies: _values(_allergies),
            conditions: _values(_conditions),
            preferredLanguage:
                _language.text.trim().isEmpty ? 'en' : _language.text.trim(),
            emergencyContact: emergency.values.every((value) => value.isEmpty)
                ? null
                : emergency,
            idempotencyKey: _idempotencyKey,
          );
      if (mounted) Navigator.pop<FamilyProfileAccess>(context, result);
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
          content: Text('Could not add this family member. Please retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add family member')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('How would you like to add them?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                  'Choose an existing account only when the person can approve the connection.'),
              const SizedBox(height: 24),
              _ChoiceCard(
                icon: Icons.person_search_outlined,
                title: 'Existing Medical Vault User',
                subtitle:
                    'Find their Medical Vault ID, registered email, or phone number and send a consent request.',
                onTap: () => setState(() => _mode = 'existing'),
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.family_restroom_rounded,
                title: 'Create Managed Family Profile',
                subtitle: _managedProfileAvailability,
                enabled: !_managedProfileLimitReached,
                onTap: () => setState(() => _mode = 'managed'),
              ),
            ],
          ),
        ),
      );
    }
    if (_mode == 'existing') {
      return ExistingMedicalVaultUserConnectionScreen(
        onBack: () => setState(() => _mode = null),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Add family member')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('Who are you caring for?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                  'This creates a managed health profile. It does not create login credentials.'),
              const SizedBox(height: 20),
              const _SectionLabel('Profile type'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.family_restroom_rounded),
                title: Text('Managed dependent'),
                subtitle: Text(
                    'An adult account link can be requested in a later release.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Full name', border: OutlineInputBorder()),
                validator: (value) => _required(value, 'displayName'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationship,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Your relationship',
                    hintText: 'Parent, child, spouse…',
                    border: OutlineInputBorder()),
                validator: (value) => _required(value, 'relationship'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateOfBirth,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder()),
                validator: _dateError,
              ),
              const SizedBox(height: 16),
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
                  DropdownMenuItem(
                      value: 'non_binary', child: Text('Non-binary')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                  DropdownMenuItem(
                      value: 'prefer_not_to_say',
                      child: Text('Prefer not to say')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _gender = value ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                decoration: InputDecoration(
                    labelText: 'Timezone',
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['timezone']),
                items: TimezoneProvider.supportedTimeZones
                    .map((zone) => DropdownMenuItem(
                        value: zone.id, child: Text(zone.label)))
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _timezone = value ?? _timezone),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Optional health details'),
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
                  DropdownMenuItem(value: 'O-', child: Text('O-')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _bloodGroup = value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _allergies,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Allergies',
                    hintText: 'Comma-separated',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditions,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Medical conditions',
                    hintText: 'Comma-separated',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _language,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: 'Preferred language',
                    hintText: 'en or en-IN',
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['preferredLanguage']),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Emergency contact (optional)'),
              TextFormField(
                  controller: _emergencyName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Contact name', border: OutlineInputBorder())),
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
                    errorText: _fieldErrors['emergencyContact']),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(_saving ? 'Adding…' : 'Add family member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon,
                  size: 32,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.38)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              )),
              Icon(enabled ? Icons.chevron_right : Icons.info_outline,
                  color: enabled
                      ? null
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.38)),
            ]),
          ),
        ),
      );
}

class ExistingMedicalVaultUserConnectionScreen extends StatefulWidget {
  const ExistingMedicalVaultUserConnectionScreen(
      {super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<ExistingMedicalVaultUserConnectionScreen> createState() =>
      _ExistingMedicalVaultUserConnectionScreenState();
}

class _ExistingMedicalVaultUserConnectionScreenState
    extends State<ExistingMedicalVaultUserConnectionScreen> {
  final _query = TextEditingController();
  final _relationship = TextEditingController();
  List<FamilyUserSearchResult> _results = const [];
  FamilyUserSearchResult? _selected;
  bool _searching = false;
  bool _sending = false;
  String _role = 'secondaryCaregiver';

  @override
  void dispose() {
    _query.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _selected = null;
      _results = const [];
    });
    try {
      final results = await context
          .read<FamilyDashboardProvider>()
          .searchExistingUsers(query);
      if (mounted) setState(() => _results = results);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not search Medical Vault accounts.')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    final selected = _selected;
    if (selected == null || _relationship.text.trim().isEmpty || _sending)
      return;
    setState(() => _sending = true);
    try {
      await context
          .read<FamilyDashboardProvider>()
          .requestExistingUserConnection(
            targetUserId: selected.id,
            relationship: _relationship.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Consent request sent. No profile data is shared until acceptance.')));
      Navigator.pop(context);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the connection request.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
          title: const Text('Connect Medical Vault User'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                  'Search uses an exact Medical Vault ID, registered email, or phone number. Results are masked to protect privacy.'),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                      labelText: 'Medical Vault ID, email, or phone',
                      border: OutlineInputBorder()),
                )),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _searching ? null : _search,
                    child: _searching
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Search')),
              ]),
              if (!_searching && _results.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text('No account is selected.')),
              for (final result in _results)
                RadioListTile<FamilyUserSearchResult>(
                  value: result,
                  groupValue: _selected,
                  onChanged: (value) => setState(() => _selected = value),
                  title: Text(result.displayName),
                  subtitle: Text([result.maskedEmail, result.maskedPhone]
                      .where((item) => item.isNotEmpty)
                      .join(' • ')),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _relationship,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Your relationship',
                    hintText: 'Daughter, spouse, caregiver…',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                    labelText: 'Requested role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'primaryCaregiver',
                      child: Text('Primary caregiver')),
                  DropdownMenuItem(
                      value: 'secondaryCaregiver',
                      child: Text('Secondary caregiver')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  DropdownMenuItem(
                      value: 'emergencyContact',
                      child: Text('Emergency contact')),
                ],
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _role = value ?? _role),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _selected == null ||
                        _relationship.text.trim().isEmpty ||
                        _sending
                    ? null
                    : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: const Text('Send consent request'),
              ),
            ],
          ),
        ),
      );
}
