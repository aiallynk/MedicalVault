import 'package:flutter/material.dart';

import '../data/models/family_dashboard.dart';

class FamilyMemberCard extends StatelessWidget {
  const FamilyMemberCard(
      {super.key, required this.member, required this.onTap});
  final FamilyDashboardMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon, String label) =
        switch (member.medicationState) {
      FamilyDataState.complete => (
          Colors.green,
          Icons.check_circle_outline,
          'On track'
        ),
      FamilyDataState.needsAttention => (
          Colors.amber.shade800,
          Icons.warning_amber_rounded,
          'Needs attention'
        ),
      FamilyDataState.upcoming => (
          colorScheme.primary,
          Icons.schedule_rounded,
          'Upcoming'
        ),
      FamilyDataState.restricted => (
          Colors.grey,
          Icons.lock_outline_rounded,
          'Restricted'
        ),
      FamilyDataState.failed => (
          colorScheme.error,
          Icons.error_outline_rounded,
          'Could not load'
        ),
      FamilyDataState.noData => (
          Colors.grey,
          Icons.info_outline_rounded,
          'No medicine data'
        ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(member.profile.displayName.isEmpty
                        ? '?'
                        : member.profile.displayName.characters.first
                            .toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.profile.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if ((member.profile.relationship ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(member.profile.relationship!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 5),
                          Text(label,
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(
                      icon: Icons.medication_outlined,
                      text: member.medicinesScheduled == 0
                          ? 'No doses scheduled'
                          : '${member.medicinesTaken} of ${member.medicinesScheduled} taken'),
                  _Metric(
                      icon: Icons.calendar_today_outlined,
                      text: member.appointmentsToday == 0
                          ? 'No appointment today'
                          : '${member.appointmentsToday} today'),
                  if (member.recentDocuments > 0)
                    _Metric(
                        icon: Icons.description_outlined,
                        text: '${member.recentDocuments} recent records'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(text),
        ]),
      );
}
