import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _guideSeenPreference = 'family_care_guide_seen_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FamilyDashboardProvider>().load();
      _showFirstVisitGuide();
    });
  }

  Future<void> _showFirstVisitGuide() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_guideSeenPreference) == true || !mounted) return;
      await _showGuide(barrierDismissible: false);
      await preferences.setBool(_guideSeenPreference, true);
    } catch (_) {
      // The guide is supplementary; Family Care remains usable if local
      // preferences are unavailable (for example, during a storage outage).
    }
  }

  Future<void> _showGuide({bool barrierDismissible = true}) => showDialog<void>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (_) => const _FamilyCareGuideDialog(),
      );

  Future<void> _openDetail(String profileId) async {
    await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => FamilyMemberDetailScreen(profileId: profileId)));
  }

  Future<void> _addMember() async {
    final result = await Navigator.push<FamilyProfileAccess>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(
          managedProfileCount: context
              .read<FamilyDashboardProvider>()
              .dashboard
              ?.managedProfileCount,
          managedProfileLimit: context
              .read<FamilyDashboardProvider>()
              .dashboard
              ?.managedProfileLimit,
        ),
      ),
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
      appBar: AppBar(
        title: const Text('Family Care'),
        actions: [
          IconButton(
            tooltip: 'How Family Care works',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showGuide,
          ),
        ],
      ),
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
          Text('Family profiles',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Choose a profile to view only its relevant care details.'),
          if (dashboard.managedProfileCount != null &&
              dashboard.managedProfileLimit != null) ...[
            const SizedBox(height: 12),
            _ManagedProfileUsage(
              used: dashboard.managedProfileCount!,
              limit: dashboard.managedProfileLimit!,
            ),
          ],
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

class _ManagedProfileUsage extends StatelessWidget {
  const _ManagedProfileUsage({required this.used, required this.limit});

  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFull = used >= limit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isFull ? Icons.info_outline_rounded : Icons.group_outlined,
            size: 19,
            color: isFull ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Managed profiles: $used of $limit used',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyCareGuideDialog extends StatefulWidget {
  const _FamilyCareGuideDialog();

  @override
  State<_FamilyCareGuideDialog> createState() => _FamilyCareGuideDialogState();
}

class _FamilyCareGuideDialogState extends State<_FamilyCareGuideDialog> {
  final _controller = PageController();
  var _page = 0;

  static const _pages = [
    (
      Icons.family_restroom_rounded,
      'Family Care, simply explained',
      'Family Care lets you keep separate health profiles for people you look after. Their information stays separate from your own profile.',
    ),
    (
      Icons.person_add_alt_1_rounded,
      'Add the right type of member',
      'Choose “Existing Medical Vault User” when the person has their own account and can approve the connection. Choose “Managed Family Profile” for a dependent who does not need a login.',
    ),
    (
      Icons.touch_app_outlined,
      'Use one profile at a time',
      'Tap a family card to manage that person’s medicines, appointments, emergency details, and permitted records. The dashboard only shows a short summary so it stays easy to scan.',
    ),
    (
      Icons.verified_user_outlined,
      'You stay in control',
      'Connections require consent where needed. Only people with the right permissions can see or update a profile. You can review access controls from each profile.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Text('How to use Family Care',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close guide',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16)),
                            child:
                                Icon(item.$1, color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 24),
                          Text(item.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(item.$3,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.45)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Text('${_page + 1} of ${_pages.length}',
                      style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == _pages.length - 1 ? 'Got it' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
