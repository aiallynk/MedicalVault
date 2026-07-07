import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../localization/app_localizations.dart';
import '../../utils/timezone_utils.dart';

class MyLostReportsPage extends StatefulWidget {
  const MyLostReportsPage({super.key});

  @override
  State<MyLostReportsPage> createState() => _MyLostReportsPageState();
}

class _MyLostReportsPageState extends State<MyLostReportsPage> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchMyLostReports();
      if (!mounted) return;
      setState(() {
        _reports = data;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case "under_review":
        return Colors.blue.shade600;
      case "matched":
        return Colors.green.shade600;
      case "found":
      case "resolved":
        return Colors.teal.shade600;
      case "closed":
        return theme.colorScheme.outline;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case "under_review":
        return l10n.auto('Under review');
      case "matched":
        return l10n.t('myLostReports.status.matched');
      case "found":
        return l10n.auto('Found');
      case "resolved":
        return l10n.auto('Resolved');
      case "closed":
        return l10n.t('myLostReports.status.closed');
      default:
        return l10n.t('myLostReports.status.open');
    }
  }

  String _formatDate(BuildContext context, String? iso, AppLocalizations l10n) {
    if (iso == null || iso.isEmpty) {
      return l10n.t('myLostReports.timeUnknown');
    }
    return formatDateTimeForContext(
      context,
      iso,
      pattern: 'MMM d, yyyy - h:mm a',
      fallback: l10n.t('myLostReports.timeUnknown'),
    );
  }

  Widget _buildReportCard(
      Map<String, dynamic> report, ThemeData theme, AppLocalizations l10n) {
    final status = report["status"]?.toString() ?? "open";
    final photoUrl = report["photoUrl"]?.toString();
    final dynamic matchedRaw = report["matchedFoundReportId"];
    final Map<String, dynamic>? matched =
        matchedRaw is Map<String, dynamic> ? matchedRaw : null;
    final lastSeenLocation =
        (report["lastSeenLocationText"] ?? report["foundLocation"] ?? '')
            .toString()
            .trim();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoUrl != null && photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      headers: const {
                        'Cache-Control': 'max-age=3600',
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Log error for debugging but show fallback UI
                        debugPrint(
                            'Image load error: $error for URL: $photoUrl');
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_search,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 36,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report["personName"]?.toString().isNotEmpty == true
                            ? report["personName"].toString()
                            : l10n.t('myLostReports.card.unnamed'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(_statusLabel(status, l10n)),
                            backgroundColor:
                                _statusColor(status, theme).withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: _statusColor(status, theme),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (report["approxAge"] != null)
                            Chip(
                              label: Text(
                                l10n.format('myLostReports.card.ageApprox',
                                    {'age': report["approxAge"].toString()}),
                              ),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                            ),
                          if (report["gender"] != null)
                            Chip(
                              label: Text(report["gender"].toString()),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.format('myLostReports.card.lastSeen', {
                'time': _formatDate(
                  context,
                  report["lastSeenTime"]?.toString(),
                  l10n,
                )
              }),
              style: theme.textTheme.bodyMedium,
            ),
            if (lastSeenLocation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastSeenLocation,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (report["description"] != null &&
                report["description"].toString().isNotEmpty)
              Text(
                report["description"].toString(),
                style: theme.textTheme.bodyMedium,
              ),
            if (matched != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.handshake, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('myLostReports.card.matchSuggested'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (matched["currentHospitalId"] != null)
                            Text(
                              l10n.format(
                                  'myLostReports.card.currentFacility', {
                                'facility':
                                    matched["currentHospitalId"].toString()
                              }),
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (matched["condition"] != null)
                            Text(
                              l10n.format('myLostReports.card.condition', {
                                'condition': matched["condition"].toString()
                              }),
                              style: theme.textTheme.bodyMedium,
                            ),
                          Text(
                            l10n.format('myLostReports.card.lastUpdated', {
                              'time': _formatDate(
                                context,
                                matched["foundTime"]?.toString(),
                                l10n,
                              )
                            }),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('myLostReports.title')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReports,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                l10n.t('myLostReports.error.title'),
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.format('common.errorWithMessage',
                                    {'message': _error!}),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadReports,
                                child: Text(l10n.t('common.retry')),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  : _reports.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.search_off,
                                      size: 56,
                                      color: theme.colorScheme.outline),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.t('myLostReports.empty.title'),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.t('myLostReports.empty.subtitle'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final report =
                                Map<String, dynamic>.from(_reports[index]);
                            return _buildReportCard(report, theme, l10n);
                          },
                        ),
        ),
      ),
    );
  }
}
