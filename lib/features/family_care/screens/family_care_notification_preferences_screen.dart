import 'package:flutter/material.dart';

import '../data/family_care_api.dart';
import '../data/family_care_repository.dart';
import '../data/models/family_care_extensions.dart';

class FamilyCareNotificationPreferencesScreen extends StatefulWidget {
  const FamilyCareNotificationPreferencesScreen({super.key, this.profileId});
  final String? profileId;

  @override
  State<FamilyCareNotificationPreferencesScreen> createState() =>
      _FamilyCareNotificationPreferencesScreenState();
}

class _FamilyCareNotificationPreferencesScreenState
    extends State<FamilyCareNotificationPreferencesScreen> {
  final _repository = FamilyCareRepository();
  FamilyCareNotificationPreferences? _preferences;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await _repository.getNotificationPreferences(
          profileId: widget.profileId);
      if (mounted) setState(() => _preferences = preferences);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String key, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final preferences = await _repository.updateNotificationPreferences(
          {key: value},
          profileId: widget.profileId);
      if (mounted) setState(() => _preferences = preferences);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateQuietHours(
      {bool? enabled, String? start, String? end}) async {
    final current = _preferences?.quietHours;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final preferences = await _repository.updateNotificationPreferences({
        'quietHours': {
          'enabled': enabled ?? current?.enabled ?? false,
          'start': start ?? current?.start ?? '22:00',
          'end': end ?? current?.end ?? '07:00',
          'timezone': current?.timezone ?? 'Asia/Kolkata',
        },
      }, profileId: widget.profileId);
      if (mounted) setState(() => _preferences = preferences);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickQuietTime({required bool start}) async {
    final value =
        start ? _preferences?.quietHours.start : _preferences?.quietHours.end;
    final parts = (value ?? (start ? '22:00' : '07:00')).split(':');
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 0,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
    );
    if (chosen == null || !mounted) return;
    final formatted =
        '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}';
    await _updateQuietHours(
        start: start ? formatted : null, end: start ? null : formatted);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _preferences;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.profileId == null
              ? 'Family Care notifications'
              : 'Member notification preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'Notifications do not change medication schedules. Each caregiver chooses their own delivery preferences.'),
                const SizedBox(height: 12),
                Card(
                    child: Column(children: [
                  _Switch(
                      title: 'Master Family Care notifications',
                      value: prefs?.enabled ?? true,
                      onChanged: (v) => _update('enabled', v)),
                  _Switch(
                      title: 'Medicine due',
                      value: prefs?.medicineDue ?? true,
                      onChanged: (v) => _update('medicineDue', v)),
                  _Switch(
                      title: 'Repeat reminder',
                      value: prefs?.repeatReminder ?? true,
                      onChanged: (v) => _update('repeatReminder', v)),
                  _Switch(
                      title: 'Medicine missed',
                      value: prefs?.medicineMissed ?? true,
                      onChanged: (v) => _update('medicineMissed', v)),
                  _Switch(
                      title: 'Caregiver missed-dose alert',
                      value: prefs?.caregiverMissedDoseAlert ?? true,
                      onChanged: (v) => _update('caregiverMissedDoseAlert', v)),
                  _Switch(
                      title: 'Taken confirmation',
                      value: prefs?.takenConfirmation ?? false,
                      onChanged: (v) => _update('takenConfirmation', v)),
                  _Switch(
                      title: 'Skipped confirmation',
                      value: prefs?.skippedConfirmation ?? false,
                      onChanged: (v) => _update('skippedConfirmation', v)),
                  _Switch(
                      title: 'Refill reminder',
                      value: prefs?.refillReminder ?? true,
                      onChanged: (v) => _update('refillReminder', v)),
                  _Switch(
                      title: 'Low-stock reminder',
                      value: prefs?.lowStockReminder ?? true,
                      onChanged: (v) => _update('lowStockReminder', v)),
                ])),
                const SizedBox(height: 16),
                Text('Quiet hours',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Card(
                    child: Column(children: [
                  _Switch(
                    title: 'Silence Family Care delivery during quiet hours',
                    value: prefs?.quietHours.enabled ?? false,
                    onChanged: (value) => _updateQuietHours(enabled: value),
                  ),
                  ListTile(
                    enabled: prefs?.quietHours.enabled ?? false,
                    title: const Text('Starts'),
                    subtitle: Text(prefs?.quietHours.start ?? '22:00'),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: (prefs?.quietHours.enabled ?? false)
                        ? () => _pickQuietTime(start: true)
                        : null,
                  ),
                  ListTile(
                    enabled: prefs?.quietHours.enabled ?? false,
                    title: const Text('Ends'),
                    subtitle: Text(prefs?.quietHours.end ?? '07:00'),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: (prefs?.quietHours.enabled ?? false)
                        ? () => _pickQuietTime(start: false)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Timezone: ${prefs?.quietHours.timezone ?? 'Asia/Kolkata'}'),
                    ),
                  ),
                ])),
              ],
            ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(
      {required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
      title: Text(title), value: value, onChanged: onChanged);
}
