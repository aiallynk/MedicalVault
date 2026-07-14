import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/patient_profile.dart';
import '../providers/active_patient_profile_provider.dart';
import '../providers/family_dashboard_provider.dart';
import '../widgets/family_member_card.dart';
import 'add_family_member_screen.dart';
import 'family_member_detail_screen.dart';

class FamilyCareDashboardScreen extends StatefulWidget {
  const FamilyCareDashboardScreen({super.key});

  @override
  State<FamilyCareDashboardScreen> createState() =>
      _FamilyCareDashboardScreenState();
}

class _FamilyCareDashboardScreenState extends State<FamilyCareDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FamilyDashboardProvider>().load();
    });
  }

  Future<void> _openDetail(String profileId) async {
    await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => FamilyMemberDetailScreen(profileId: profileId)));
  }

  Future<void> _addMember() async {
    final result = await Navigator.push<FamilyProfileAccess>(
      context,
      MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${result.profile.displayName} was added to Family Care.'),
        action: SnackBarAction(
            label: 'View', onPressed: () => _openDetail(result.profile.id)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyDashboardProvider>();
    final canAdd = provider.state == FamilyDashboardLoadState.loaded ||
        provider.state == FamilyDashboardLoadState.empty;
    return Scaffold(
      appBar: AppBar(title: const Text('Family Care')),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add member'))
          : null,
      body: SafeArea(child: _body(context, provider)),
    );
  }

  Widget _body(BuildContext context, FamilyDashboardProvider provider) {
    if (provider.state == FamilyDashboardLoadState.initial ||
        provider.state == FamilyDashboardLoadState.loading) {
      return ListView(
          padding: const EdgeInsets.all(20),
          children: List.generate(
              3,
              (_) => const Card(
                  child: SizedBox(
                      height: 132,
                      child: Center(child: CircularProgressIndicator())))));
    }
    final stateMessage = switch (provider.state) {
      FamilyDashboardLoadState.unavailable => (
          'Family Care is unavailable',
          'Family Care has not been enabled for this environment yet.',
          Icons.toggle_off_outlined
        ),
      FamilyDashboardLoadState.subscriptionRequired => (
          'Family Care access is required',
          provider.errorMessage ?? 'An active Family Care plan is required.',
          Icons.workspace_premium_outlined
        ),
      FamilyDashboardLoadState.entitlementExpired => (
          'Family Care access needs attention',
          provider.errorMessage ??
              'Your Family Care access has expired or is suspended.',
          Icons.schedule_outlined
        ),
      FamilyDashboardLoadState.configurationError => (
          'Family Care is temporarily unavailable',
          provider.errorMessage ?? 'Please retry shortly.',
          Icons.settings_outlined
        ),
      FamilyDashboardLoadState.restricted => (
          'Family Care access is restricted',
          provider.errorMessage ?? 'Please contact support for access.',
          Icons.lock_outline
        ),
      FamilyDashboardLoadState.error => (
          'Family information did not load',
          provider.errorMessage ?? 'Please retry.',
          Icons.cloud_off_outlined
        ),
      _ => null,
    };
    if (stateMessage != null) {
      return _MessageState(
          icon: stateMessage.$3,
          title: stateMessage.$1,
          message: stateMessage.$2,
          action: FilledButton.icon(
              onPressed: () => provider.load(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')));
    }
    final dashboard = provider.dashboard;
    if (provider.state == FamilyDashboardLoadState.empty ||
        dashboard == null ||
        dashboard.members.isEmpty) {
      return _MessageState(
          icon: Icons.family_restroom_rounded,
          title: 'Add a family member',
          message:
              'Manage medicines, appointments, records and reminders for the people you care for.',
          action: FilledButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.add),
              label: const Text('Add family member')));
    }
    return RefreshIndicator(
      onRefresh: () => provider.load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text('Your family today',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              '${dashboard.members.length} health profile${dashboard.members.length == 1 ? '' : 's'} • ${dashboard.timezone}'),
          const SizedBox(height: 18),
          for (final member in dashboard.members) ...[
            FamilyMemberCard(
              member: member,
              onTap: () {
                context
                    .read<ActivePatientProfileProvider>()
                    .select(member.profile);
                _openDetail(member.profile.id);
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}
