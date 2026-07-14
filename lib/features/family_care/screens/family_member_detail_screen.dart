import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/family_care_api.dart';
import '../data/models/patient_profile.dart';
import '../providers/active_patient_profile_provider.dart';
import '../providers/family_dashboard_provider.dart';
import 'edit_family_member_screen.dart';
import 'family_member_medicines_screen.dart';
import 'family_member_appointments_screen.dart';
import 'managed_profile_link_account_screen.dart';
import 'family_care_notification_preferences_screen.dart';

class FamilyMemberDetailScreen extends StatefulWidget {
  const FamilyMemberDetailScreen({
    super.key,
    required this.profileId,
    this.initialTab = 0,
    this.highlightedDoseEventId,
  });

  final String profileId;
  final int initialTab;
  final String? highlightedDoseEventId;

  @override
  State<FamilyMemberDetailScreen> createState() =>
      _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState extends State<FamilyMemberDetailScreen> {
  FamilyProfileAccess? _access;
  String? _error;
  bool _loading = true;
  bool _archiving = false;

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
      final access = await context
          .read<FamilyDashboardProvider>()
          .getProfile(widget.profileId);
      if (mounted) {
        context.read<ActivePatientProfileProvider>().select(access.profile);
        setState(() => _access = access);
      }
    } on FamilyCareApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not load this family profile. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final access = _access;
    if (access == null) return;
    final result = await Navigator.push<FamilyProfileAccess>(
      context,
      MaterialPageRoute(builder: (_) => EditFamilyMemberScreen(access: access)),
    );
    if (result != null && mounted) setState(() => _access = result);
  }

  Future<void> _archive() async {
    final access = _access;
    if (access == null || _archiving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this family profile?'),
        content: const Text(
          'The profile will be removed from your active Family Care dashboard. '
          'Existing healthcare history will be retained.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = true);
    try {
      await context
          .read<FamilyDashboardProvider>()
          .archiveProfile(access.profile.id);
      if (!mounted) return;
      final active = context.read<ActivePatientProfileProvider>();
      if (active.activeProfileId == access.profile.id) active.clear();
      Navigator.pop(context, true);
    } on FamilyCareApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not archive this family profile. Please retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family member'),
        actions: [
          if (access?.permissions['profileEdit'] == true)
            IconButton(
                onPressed: _edit,
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined)),
          if (access?.role == 'owner')
            IconButton(
              onPressed: _archiving ? null : _archive,
              tooltip: 'Archive profile',
              icon: _archiving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : access == null
                    ? _ErrorState(
                        message: 'Profile was not found.', onRetry: _load)
                    : _MemberTabs(
                        access: access,
                        initialTab: widget.initialTab,
                        highlightedDoseEventId: widget.highlightedDoseEventId,
                      ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.access});
  final FamilyProfileAccess access;

  String _age(String? dateOfBirth) {
    final birth = DateTime.tryParse(dateOfBirth ?? '');
    if (birth == null) return 'Not available';
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years -= 1;
    }
    return '$years years';
  }

  @override
  Widget build(BuildContext context) {
    final profile = access.profile;
    final initials = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim().characters.first.toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
                radius: 32,
                child: Text(initials,
                    style: Theme.of(context).textTheme.headlineSmall)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(profile.relationship ?? access.relationship,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Chip(label: Text('${access.role} access')),
                  ]),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Overview',
          children: [
            _InfoRow(
                label: 'Date of birth',
                value: profile.dateOfBirth ?? 'Not available'),
            _InfoRow(label: 'Age', value: _age(profile.dateOfBirth)),
            _InfoRow(label: 'Gender', value: profile.gender ?? 'Not specified'),
            _InfoRow(
                label: 'Blood group',
                value: profile.bloodGroup ?? 'Not specified'),
            _InfoRow(label: 'Timezone', value: profile.timezone),
            _InfoRow(
                label: 'Preferred language', value: profile.preferredLanguage),
          ],
        ),
        _Section(
          title: 'Health summary',
          children: [
            _InfoRow(
                label: 'Allergies',
                value: profile.allergies.isEmpty
                    ? 'None recorded'
                    : profile.allergies.join(', ')),
            _InfoRow(
                label: 'Conditions',
                value: profile.conditions.isEmpty
                    ? 'None recorded'
                    : profile.conditions.join(', ')),
          ],
        ),
        _Section(
          title: 'Emergency contact',
          children: [
            _InfoRow(
                label: 'Name',
                value: profile.emergencyContact.name.isEmpty
                    ? 'Not recorded'
                    : profile.emergencyContact.name),
            _InfoRow(
                label: 'Relationship',
                value: profile.emergencyContact.relationship.isEmpty
                    ? 'Not recorded'
                    : profile.emergencyContact.relationship),
            _InfoRow(
                label: 'Phone',
                value: profile.emergencyContact.phone.isEmpty
                    ? 'Not recorded'
                    : profile.emergencyContact.phone),
          ],
        ),
        _Section(
          title: 'Your access',
          children: [
            _InfoRow(label: 'Role', value: access.role),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: access.permissions.entries
                  .where((entry) => entry.value)
                  .map((entry) => Chip(label: Text(entry.key)))
                  .toList(growable: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemberTabs extends StatelessWidget {
  const _MemberTabs(
      {required this.access,
      required this.initialTab,
      this.highlightedDoseEventId});
  final FamilyProfileAccess access;
  final int initialTab;
  final String? highlightedDoseEventId;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        initialIndex: initialTab.clamp(0, 5),
        length: 6,
        child: Column(children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Medicines'),
                Tab(text: 'Appointments'),
                Tab(text: 'Documents'),
                Tab(text: 'Caregivers'),
                Tab(text: 'More'),
              ],
            ),
          ),
          Expanded(
              child: TabBarView(children: [
            _OverviewBody(access: access),
            FamilyMemberMedicinesScreen(
              profileId: access.profile.id,
              canManage: access.permissions['medicationsManage'] == true,
              timezone: access.profile.timezone,
              highlightedDoseEventId: highlightedDoseEventId,
            ),
            FamilyMemberAppointmentsScreen(
              profileId: access.profile.id,
              canManage: access.permissions['appointmentsManage'] == true,
            ),
            const _UnavailableScope(
                title: 'Documents',
                message:
                    'Profile-scoped document access is not enabled in this release.'),
            _CaregiversTab(access: access),
            _MoreTab(access: access),
          ])),
        ]),
      );
}

class _UnavailableScope extends StatelessWidget {
  const _UnavailableScope({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline,
              size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ]),
      ));
}

class _CaregiversTab extends StatelessWidget {
  const _CaregiversTab({required this.access});
  final FamilyProfileAccess access;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _Section(title: 'Your caregiver role', children: [
          _InfoRow(label: 'Role', value: access.role),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: access.permissions.entries
                  .where((entry) => entry.value)
                  .map((entry) => Chip(label: Text(entry.key)))
                  .toList()),
        ]),
        const _Section(title: 'Connection status', children: [
          _InfoRow(label: 'Status', value: 'Active Family Care connection'),
          _InfoRow(
              label: 'Privacy',
              value:
                  'Access is enforced by this profile’s active relationship.'),
        ]),
      ]);
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.access});
  final FamilyProfileAccess access;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _Section(title: 'Profile', children: [
          _InfoRow(
              label: 'Profile type',
              value: access.profile.profileType == 'managed'
                  ? 'Managed Profile'
                  : 'Linked Medical Vault User'),
          _InfoRow(label: 'Timezone', value: access.profile.timezone),
        ]),
        if (access.profile.profileType == 'managed' && access.role == 'owner')
          _Section(title: 'Account linking', children: [
            const Text(
                'If this person now has their own account, send a consent request. Existing data is preserved and conflicts require merge review.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ManagedProfileLinkAccountScreen(
                      profileId: access.profile.id,
                      relationship: access.relationship))),
              icon: const Icon(Icons.link),
              label: const Text('Link Existing Medical Vault Account'),
            ),
          ]),
        _Section(title: 'Notifications', children: [
          const Text(
              'Set the medicine and missed-dose alerts you receive for this family member.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FamilyCareNotificationPreferencesScreen(
                    profileId: access.profile.id))),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Notification preferences'),
          ),
        ]),
      ]);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 122,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
}
