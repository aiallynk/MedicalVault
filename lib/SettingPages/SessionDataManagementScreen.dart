import 'package:flutter/material.dart';

import '../api_service.dart';
import '../widgets/app_text.dart';
import '../widgets/settings_primitives.dart';
import '../screens/guest_clinical_session_screen.dart';

/// Settings -> Controls -> Session Data Management.
///
/// Lets the patient set persistent DEFAULTS for what a doctor sees during a
/// future session-access approval. These are only defaults: they pre-fill
/// the per-session approval screen, they never themselves grant access (see
/// SessionApprovalScreen / SessionAccessGrant on the backend).
class SessionDataManagementScreen extends StatefulWidget {
  const SessionDataManagementScreen({super.key});

  @override
  State<SessionDataManagementScreen> createState() =>
      _SessionDataManagementScreenState();
}

const List<(String key, String label)> _categoryFields = [
  ('Report', 'Reports'),
  ('Prescription', 'Prescriptions'),
  ('Bill', 'Bills'),
  ('Insurance', 'Insurance'),
];

const List<(String key, String label, String subtitle)> _structuredFields = [
  ('profile', 'Basic medical profile', 'Name, age, gender, blood type.'),
  ('allergies', 'Allergies', 'Known allergies on file.'),
  ('conditions', 'Medical conditions', 'Diagnosed conditions and their status.'),
  ('medications', 'Current medications', 'Active prescriptions and dosages.'),
  ('emergencyInformation', 'Emergency information', 'Emergency contact details.'),
  ('appointments', 'Appointment history', 'Past and upcoming appointments.'),
];

const Map<String, String> _categoryStateLabels = {
  'share': 'Share by default',
  'ask': 'Ask every time',
  'deny': 'Do not share',
};

const Map<String, IconData> _categoryStateIcons = {
  'share': Icons.check_circle_outline_rounded,
  'ask': Icons.help_outline_rounded,
  'deny': Icons.block_rounded,
};

const _recommendedDefaults = <String, dynamic>{
  'categoryDefaults': {
    'Report': 'ask',
    'Prescription': 'ask',
    'Bill': 'deny',
    'Insurance': 'deny',
  },
  'structuredDataDefaults': {
    'profile': true,
    'allergies': true,
    'conditions': true,
    'medications': true,
    'appointments': false,
    'emergencyInformation': true,
  },
  'capabilities': {
    'allowDoctorDownload': false,
    'allowDoctorUploadToPatient': true,
  },
};

class _SessionDataManagementScreenState
    extends State<SessionDataManagementScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _dirty = false;

  Map<String, String> _categoryDefaults = {};
  Map<String, bool> _structuredDataDefaults = {};
  bool _allowDownload = false;
  bool _allowUpload = true;

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
    final preferences = await ApiService.fetchSharingPreferences();
    if (!mounted) return;
    if (preferences == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load your sharing controls. Please try again.';
      });
      return;
    }
    _applyPreferences(preferences);
    setState(() {
      _loading = false;
      _dirty = false;
    });
  }

  void _applyPreferences(Map<String, dynamic> preferences) {
    final categoryDefaults = preferences['categoryDefaults'];
    _categoryDefaults = {
      for (final field in _categoryFields)
        field.$1: categoryDefaults is Map
            ? (categoryDefaults[field.$1] ?? 'ask').toString()
            : 'ask',
    };
    final structuredDefaults = preferences['structuredDataDefaults'];
    _structuredDataDefaults = {
      for (final field in _structuredFields)
        field.$1: structuredDefaults is Map
            ? structuredDefaults[field.$1] == true
            : false,
    };
    final capabilities = preferences['capabilities'];
    _allowDownload = capabilities is Map && capabilities['allowDoctorDownload'] == true;
    _allowUpload = capabilities is! Map || capabilities['allowDoctorUploadToPatient'] != false;
  }

  Future<void> _pickCategoryState(String categoryKey, String categoryLabel) async {
    final scheme = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  categoryLabel,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface),
                ),
              ),
            ),
            for (final state in ['share', 'ask', 'deny'])
              ListTile(
                leading: Icon(_categoryStateIcons[state], color: scheme.primary),
                title: Text(_categoryStateLabels[state] ?? state),
                trailing: _categoryDefaults[categoryKey] == state
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(state),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _categoryDefaults[categoryKey] = selected;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes to your sharing controls.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _resetToRecommended() async {
    setState(() {
      _applyPreferences(_recommendedDefaults);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = await ApiService.updateSharingPreferences(
      categoryDefaults: _categoryDefaults,
      structuredDataDefaults: _structuredDataDefaults,
      capabilities: {
        'allowDoctorDownload': _allowDownload,
        'allowDoctorUploadToPatient': _allowUpload,
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save your changes. Please try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: _save),
        ),
      );
      return;
    }
    _applyPreferences(updated);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing controls saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscardIfDirty() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Session Data Management'),
          actions: [
            if (!_loading && _error == null)
              TextButton(
                onPressed: _saving ? null : _resetToRecommended,
                child: const Text('Reset'),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsTokens.pageHorizontal,
                      16,
                      SettingsTokens.pageHorizontal,
                      100,
                    ),
                    children: [
                      SettingsSection(
                        title: 'Guest clinical session',
                        subtitle: 'Invite a clinician without a Medical Vault account for one explicitly approved session.',
                        child: SettingsGroupCard(
                          padding: EdgeInsets.zero,
                          child: SettingsItemTile(
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Start Guest Clinical Session',
                            subtitle: 'Uses email verification. Credentials remain unverified unless independently checked.',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuestClinicalSessionScreen())),
                          ),
                        ),
                      ),
                      const SizedBox(height: SettingsTokens.sectionGap),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: visuals.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: visuals.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppText(
                                'These are defaults only. You still choose exactly what to share each time a doctor requests access — this screen just pre-fills that choice.',
                                variant: AppTextVariant.caption,
                                color: visuals.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SettingsTokens.sectionGap),
                      SettingsSection(
                        title: 'Default document sharing',
                        subtitle: 'Choose how each document category behaves by default.',
                        child: SettingsGroupCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < _categoryFields.length; i++)
                                SettingsItemTile(
                                  icon: Icons.description_outlined,
                                  title: _categoryFields[i].$2,
                                  subtitle: _categoryStateLabels[_categoryDefaults[_categoryFields[i].$1]] ?? 'Ask every time',
                                  showDivider: i != _categoryFields.length - 1,
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => _pickCategoryState(
                                    _categoryFields[i].$1,
                                    _categoryFields[i].$2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: SettingsTokens.sectionGap),
                      SettingsSection(
                        title: 'Default health-data sharing',
                        subtitle: 'Choose which health information is offered by default.',
                        child: SettingsGroupCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < _structuredFields.length; i++)
                                SettingsSwitchTile(
                                  icon: Icons.health_and_safety_outlined,
                                  title: _structuredFields[i].$2,
                                  subtitle: _structuredFields[i].$3,
                                  value: _structuredDataDefaults[_structuredFields[i].$1] ?? false,
                                  showDivider: i != _structuredFields.length - 1,
                                  onChanged: (value) => setState(() {
                                    _structuredDataDefaults[_structuredFields[i].$1] = value;
                                    _dirty = true;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: SettingsTokens.sectionGap),
                      SettingsSection(
                        title: 'Doctor capability defaults',
                        subtitle: 'Control what a doctor may do with what you share.',
                        child: SettingsGroupCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              SettingsSwitchTile(
                                icon: Icons.download_outlined,
                                title: 'Allow file downloads',
                                subtitle:
                                    'The doctor may save a copy of documents shared during an active session.',
                                value: _allowDownload,
                                showDivider: true,
                                onChanged: (value) => setState(() {
                                  _allowDownload = value;
                                  _dirty = true;
                                }),
                              ),
                              SettingsSwitchTile(
                                icon: Icons.upload_outlined,
                                title: 'Allow doctor uploads',
                                subtitle:
                                    'The doctor may add prescriptions, reports or other files to your Medical Vault during an active session.',
                                value: _allowUpload,
                                onChanged: (value) => setState(() {
                                  _allowUpload = value;
                                  _dirty = true;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: (_loading || _error != null)
            ? null
            : SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _dirty
                      ? Container(
                          key: const ValueKey('save-bar'),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            color: visuals.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Save changes'),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-save-bar')),
                ),
              ),
      ),
    );
  }
}
