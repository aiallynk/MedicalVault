import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'lost_found_report_page.dart';
import 'lost_person_photo.dart';

class LostPersonDetailPage extends StatefulWidget {
  const LostPersonDetailPage({
    super.key,
    required this.reportId,
    this.currentUser = const {},
    this.linkedProfiles = const [],
  });

  final String reportId;
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> linkedProfiles;

  @override
  State<LostPersonDetailPage> createState() => _LostPersonDetailPageState();
}

class _LostPersonDetailPageState extends State<LostPersonDetailPage> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _report = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final report = await ApiService.getLostPersonDetail(widget.reportId);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFoundReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LostFoundReportPage(
          currentUser: widget.currentUser,
          linkedProfiles: widget.linkedProfiles,
          initialMode: LostFoundReportMode.found,
          relatedLostReportId: widget.reportId,
        ),
      ),
    );
  }

  String _text(String key, [String fallback = 'Not available']) {
    final value = _report[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = _report['photoUrl']?.toString().trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Lost Person Details')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      LostPersonPhoto(
                        photoUrl: photoUrl,
                        height: 260,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(16),
                        fallbackIcon: Icons.person_search_rounded,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _text('personName', 'Unnamed person'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Age: ${_text('approxAge')}')),
                          Chip(label: Text(_text('gender', 'Unknown'))),
                          Chip(
                              label:
                                  Text('Status: ${_text('status', 'open')}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoBlock(
                        title: 'Last seen location',
                        value: _text('lastSeenLocationText'),
                      ),
                      _InfoBlock(
                        title: 'Last seen time',
                        value: _text('lastSeenTime'),
                      ),
                      _InfoBlock(
                        title: 'Description',
                        value: _text('description'),
                      ),
                      _InfoBlock(
                        title: 'Clothing / identifiers',
                        value: _text('clothingDescription'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openFoundReport,
                        icon: const Icon(Icons.volunteer_activism_rounded),
                        label: const Text('I found this person'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
