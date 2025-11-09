import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api_service.dart';

class MyLostReportsPage extends StatefulWidget {
  const MyLostReportsPage({super.key});

  @override
  State<MyLostReportsPage> createState() => _MyLostReportsPageState();
}

class _MyLostReportsPageState extends State<MyLostReportsPage> {
  final DateFormat _dateFormat = DateFormat("MMM d, yyyy • h:mm a");

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
      case "matched":
        return Colors.green.shade600;
      case "closed":
        return theme.colorScheme.outline;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "matched":
        return "Matched";
      case "closed":
        return "Closed";
      default:
        return "Open";
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return "Time not recorded";
    try {
      final date = DateTime.parse(iso);
      return _dateFormat.format(date.toLocal());
    } catch (_) {
      return "Time not recorded";
    }
  }

  Widget _buildReportCard(Map<String, dynamic> report, ThemeData theme) {
    final status = report["status"]?.toString() ?? "open";
    final photoUrl = report["photoUrl"]?.toString();
    final dynamic matchedRaw = report["matchedFoundReportId"];
    final Map<String, dynamic>? matched = matchedRaw is Map<String, dynamic>
        ? matchedRaw
        : null;

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
                            : "Unnamed report",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(_statusLabel(status)),
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
                                  "Age ~${report["approxAge"].toString()}"),
                              backgroundColor:
                                  theme.colorScheme.surfaceVariant,
                            ),
                          if (report["gender"] != null)
                            Chip(
                              label: Text(report["gender"].toString()),
                              backgroundColor:
                                  theme.colorScheme.surfaceVariant,
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
              "Last seen: ${_formatDate(report["lastSeenTime"]?.toString())}",
              style: theme.textTheme.bodyMedium,
            ),
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
                          const Text(
                            "Match suggested",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (matched["currentHospitalId"] != null)
                            Text(
                              "Current facility: ${matched["currentHospitalId"]}",
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (matched["condition"] != null)
                            Text(
                              "Condition: ${matched["condition"]}",
                              style: theme.textTheme.bodyMedium,
                            ),
                          Text(
                            "Last updated: ${_formatDate(matched["foundTime"]?.toString())}",
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Lost Reports"),
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
                                "Failed to load reports",
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadReports,
                                child: const Text("Retry"),
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
                                    "No lost person reports yet",
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "When you report a lost family member, the status and suggested matches will appear here.",
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
                            return _buildReportCard(report, theme);
                          },
                        ),
        ),
      ),
    );
  }
}

