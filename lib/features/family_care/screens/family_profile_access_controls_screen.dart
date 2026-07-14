import 'package:flutter/material.dart';

import '../data/family_care_api.dart';
import '../data/family_care_repository.dart';
import '../data/models/family_care_extensions.dart';

class FamilyProfileAccessControlsScreen extends StatefulWidget {
  const FamilyProfileAccessControlsScreen({super.key});

  @override
  State<FamilyProfileAccessControlsScreen> createState() =>
      _FamilyProfileAccessControlsScreenState();
}

class _FamilyProfileAccessControlsScreenState
    extends State<FamilyProfileAccessControlsScreen> {
  final _repository = FamilyCareRepository();
  Map<String, dynamic>? _controls;
  Map<String, dynamic> _connections = const {};
  Map<String, List<FamilyInvitation>> _invitations = const {};
  bool _loading = true;
  bool _saving = false;
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
      final results = await Future.wait<dynamic>([
        _repository.getAccessControls(),
        _repository.getConnections(),
        _repository.getInvitations(),
      ]);
      if (mounted)
        setState(() {
          _controls = Map<String, dynamic>.from(results[0] as Map);
          _connections = Map<String, dynamic>.from(results[1] as Map);
          _invitations =
              Map<String, List<FamilyInvitation>>.from(results[2] as Map);
        });
    } on FamilyCareApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Could not load Family and Profile Access controls.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    if (_saving || _controls == null) return;
    setState(() => _saving = true);
    try {
      final controls = await _repository.updateAccessControls(patch);
      if (mounted) setState(() => _controls = controls);
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _respond(FamilyInvitation invitation, bool accept) async {
    try {
      await _repository.respondToInvitation(invitation.id, accept: accept);
      await _load();
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _revoke(String id) async {
    try {
      await _repository.revokeConnection(id);
      await _load();
    } on FamilyCareApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editConnection(Map<String, dynamic> connection) async {
    final id = connection['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final initialPermissions = connection['permissions'] is Map
        ? Map<String, dynamic>.from(connection['permissions'] as Map)
        : <String, dynamic>{};
    final permissions = <String, dynamic>{...initialPermissions};
    var status = (connection['status'] ?? 'active').toString();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ListView(
              children: [
                Text(
                  'Connection access',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permissions cannot exceed your own access. Suspending takes effect immediately and can be resumed later.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Connection status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (value) => setSheetState(
                    () => status = value ?? status,
                  ),
                ),
                const SizedBox(height: 12),
                for (final permission in const [
                  'profileRead',
                  'profileEdit',
                  'documentsView',
                  'documentsUpload',
                  'appointmentsView',
                  'appointmentsManage',
                  'medicationsView',
                  'medicationsManage',
                  'dosesConfirm',
                  'emergencyView',
                  'caregiverNotificationsReceive',
                  'profileContextSwitch',
                  'caregiversManage',
                ])
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_permissionLabel(permission)),
                    value: permissions[permission] == true,
                    onChanged: (value) => setSheetState(
                      () => permissions[permission] = value,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save access'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await _repository.updateConnection(id, {
        'status': status,
        'permissions': permissions,
      });
      await _load();
    } on FamilyCareApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controls = _controls;
    final defaultPermissions = controls?['defaultRequestedPermissions'] is Map
        ? Map<String, dynamic>.from(
            controls!['defaultRequestedPermissions'] as Map)
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Family and Profile Access')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _Error(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Text('Request controls',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(
                          'New requests never expose health data before your acceptance. Existing accepted connections stay active until you suspend or revoke them.'),
                      const SizedBox(height: 12),
                      Card(
                          child: Column(children: [
                        SwitchListTile.adaptive(
                          title: const Text('Allow Profile Access Requests'),
                          subtitle: const Text(
                              'Disabled by default for new accounts.'),
                          value:
                              controls?['allowProfileAccessRequests'] == true,
                          onChanged: _saving
                              ? null
                              : (value) => _update(
                                  {'allowProfileAccessRequests': value}),
                        ),
                        DropdownButtonFormField<String>(
                          value: (controls?['requestPolicy'] ?? 'nobody')
                              .toString(),
                          decoration: const InputDecoration(
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              labelText: 'Request policy'),
                          items: const [
                            DropdownMenuItem(
                                value: 'anyone_with_medical_vault_id',
                                child: Text('Anyone with my Medical Vault ID')),
                            DropdownMenuItem(
                                value: 'contacts_only',
                                child: Text('Contacts only')),
                            DropdownMenuItem(
                                value: 'existing_connections_only',
                                child: Text('Existing connections only')),
                            DropdownMenuItem(
                                value: 'nobody', child: Text('Nobody')),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => _update({'requestPolicy': value}),
                        ),
                        SwitchListTile.adaptive(
                          title:
                              const Text('Require approval for every request'),
                          value: controls?['requireApprovalForEveryRequest'] !=
                              false,
                          onChanged: _saving
                              ? null
                              : (value) => _update(
                                  {'requireApprovalForEveryRequest': value}),
                        ),
                        ExpansionTile(
                          title: const Text('Default requested permissions'),
                          subtitle: const Text(
                              'These are requests only; you can change or revoke accepted access at any time.'),
                          children: [
                            for (final permission in const [
                              'profileRead',
                              'profileEdit',
                              'documentsView',
                              'documentsUpload',
                              'appointmentsView',
                              'appointmentsManage',
                              'medicationsView',
                              'medicationsManage',
                              'dosesConfirm',
                              'emergencyView',
                              'caregiverNotificationsReceive',
                              'profileContextSwitch',
                              'caregiversManage',
                            ])
                              SwitchListTile.adaptive(
                                title: Text(_permissionLabel(permission)),
                                value: defaultPermissions[permission] == true,
                                onChanged: _saving
                                    ? null
                                    : (value) => _update({
                                          'defaultRequestedPermissions': {
                                            ...defaultPermissions,
                                            permission: value,
                                          },
                                        }),
                              ),
                          ],
                        ),
                      ])),
                      const SizedBox(height: 16),
                      _InvitationSection(
                        title: 'Pending incoming requests',
                        invitations: _invitations['incoming'] ?? const [],
                        onAccept: (item) => _respond(item, true),
                        onDecline: (item) => _respond(item, false),
                      ),
                      const SizedBox(height: 16),
                      _InvitationSection(
                        title: 'Pending outgoing requests',
                        invitations: _invitations['outgoing'] ?? const [],
                        onCancel: (item) async {
                          await _repository.cancelInvitation(item.id);
                          await _load();
                        },
                      ),
                      const SizedBox(height: 16),
                      _ConnectionSection(
                        title: 'Active connections',
                        connections: [
                          if (_connections['caregivers'] is List)
                            ..._connections['caregivers'] as List,
                          if (_connections['familyMembers'] is List)
                            ..._connections['familyMembers'] as List,
                        ],
                        onEdit: _editConnection,
                        onRevoke: _revoke,
                      ),
                    ],
                  ),
      ),
    );
  }
}

String _permissionLabel(String key) {
  const labels = {
    'profileRead': 'View profile',
    'profileEdit': 'Edit profile',
    'documentsView': 'View documents',
    'documentsUpload': 'Upload documents',
    'appointmentsView': 'View appointments',
    'appointmentsManage': 'Manage appointments',
    'medicationsView': 'View medicines',
    'medicationsManage': 'Manage medicines',
    'dosesConfirm': 'Confirm doses',
    'emergencyView': 'View emergency information',
    'caregiverNotificationsReceive': 'Receive caregiver alerts',
    'profileContextSwitch': 'Open profile context',
    'caregiversManage': 'Manage caregivers',
  };
  return labels[key] ?? key;
}

class _InvitationSection extends StatelessWidget {
  const _InvitationSection(
      {required this.title,
      required this.invitations,
      this.onAccept,
      this.onDecline,
      this.onCancel});
  final String title;
  final List<FamilyInvitation> invitations;
  final ValueChanged<FamilyInvitation>? onAccept;
  final ValueChanged<FamilyInvitation>? onDecline;
  final ValueChanged<FamilyInvitation>? onCancel;

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (invitations.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 8), child: Text('None')),
          for (final item in invitations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  '${item.relationship.isEmpty ? 'Family' : item.relationship} • ${item.role}'),
              subtitle: Text(item.kind == 'profile_link'
                  ? 'Profile link consent request'
                  : 'Family Care connection request'),
              trailing: Wrap(spacing: 4, children: [
                if (onAccept != null)
                  IconButton(
                      tooltip: 'Accept',
                      onPressed: () => onAccept!(item),
                      icon: const Icon(Icons.check)),
                if (onDecline != null)
                  IconButton(
                      tooltip: 'Decline',
                      onPressed: () => onDecline!(item),
                      icon: const Icon(Icons.close)),
                if (onCancel != null)
                  TextButton(
                      onPressed: () => onCancel!(item),
                      child: const Text('Cancel')),
              ]),
            ),
        ]),
      ));
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({
    required this.title,
    required this.connections,
    required this.onEdit,
    required this.onRevoke,
  });
  final String title;
  final List connections;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onRevoke;

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (connections.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 8), child: Text('None')),
          for (final raw in connections.whereType<Map>())
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                (raw['profile'] is Map ? raw['profile']['displayName'] : null)
                        ?.toString() ??
                    (raw['connectedUser'] is Map
                            ? raw['connectedUser']['displayName']
                            : null)
                        ?.toString() ??
                    'Family connection',
              ),
              subtitle: Text(
                  '${raw['role'] ?? 'caregiver'} • ${raw['status'] ?? 'active'}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Edit access',
                    onPressed: raw['id']?.toString().isEmpty != false
                        ? null
                        : () => onEdit(Map<String, dynamic>.from(raw)),
                    icon: const Icon(Icons.tune_outlined),
                  ),
                  TextButton(
                    onPressed: raw['id']?.toString().isEmpty != false
                        ? null
                        : () => onRevoke(raw['id'].toString()),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ),
        ]),
      ));
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ));
}
