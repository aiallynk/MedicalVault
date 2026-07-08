import 'package:flutter/material.dart';

import 'report_found_page.dart';
import 'report_lost_page.dart';

enum LostFoundReportMode { lost, found }

class LostFoundReportPage extends StatefulWidget {
  const LostFoundReportPage({
    super.key,
    required this.currentUser,
    required this.linkedProfiles,
    this.initialMode = LostFoundReportMode.lost,
    this.relatedLostReportId,
  });

  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> linkedProfiles;
  final LostFoundReportMode initialMode;
  final String? relatedLostReportId;

  @override
  State<LostFoundReportPage> createState() => _LostFoundReportPageState();
}

class _LostFoundReportPageState extends State<LostFoundReportPage> {
  late LostFoundReportMode _mode = widget.initialMode;

  Future<void> _openSelectedFlow() async {
    final page = _mode == LostFoundReportMode.lost
        ? ReportLostPage(
            currentUser: widget.currentUser,
            linkedProfiles: widget.linkedProfiles,
          )
        : const ReportFoundPage();

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLost = _mode == LostFoundReportMode.lost;

    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Found')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<LostFoundReportMode>(
              segments: const [
                ButtonSegment(
                  value: LostFoundReportMode.lost,
                  icon: Icon(Icons.person_search_rounded),
                  label: Text('Lost Person'),
                ),
                ButtonSegment(
                  value: LostFoundReportMode.found,
                  icon: Icon(Icons.volunteer_activism_rounded),
                  label: Text('Found Person'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() => _mode = value.first);
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isLost
                          ? Icons.person_search_rounded
                          : Icons.volunteer_activism_rounded,
                      color: theme.colorScheme.primary,
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isLost ? 'Report a lost person' : 'Report a found person',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLost
                          ? 'Add photo, identity details, last-seen time, and last-seen location.'
                          : 'Share safe details, current location, photo, and condition so admins can match reports.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (widget.relatedLostReportId?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 12),
                      Chip(
                        avatar: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          'Linked lost report: ${widget.relatedLostReportId}',
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openSelectedFlow,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          isLost
                              ? 'Continue lost report'
                              : 'Continue found report',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_rounded),
                title: const Text('Privacy protected'),
                subtitle: const Text(
                  'Search and AI results show only public lost-person report fields.',
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
