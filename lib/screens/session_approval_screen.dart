import 'package:flutter/material.dart';

import '../api_service.dart';

/// The patient's approval screen for a doctor's session access request.
/// Shown when accepting a request from Requests.dart — the patient decides
/// exactly which documents, structured-data sections, and doctor
/// capabilities are shared for this session before it starts.
class SessionApprovalScreen extends StatefulWidget {
  const SessionApprovalScreen({
    super.key,
    required this.sessionId,
    required this.doctorName,
    this.doctorAvatarUrl,
    this.doctorSpecialization,
  });

  final String sessionId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String? doctorSpecialization;

  @override
  State<SessionApprovalScreen> createState() => _SessionApprovalScreenState();
}

class _CategoryState {
  _CategoryState({
    required this.category,
    required this.documentCount,
    required this.documents,
    required this.defaultState,
  });

  final String category;
  final int documentCount;
  final List<Map<String, dynamic>> documents;
  final String defaultState; // share | ask | deny
  final Set<String> selectedIds = <String>{};
  bool expanded = false;
}

const Map<String, String> _structuredDataLabels = {
  'profile': 'Basic medical profile',
  'allergies': 'Allergies',
  'conditions': 'Medical conditions',
  'medications': 'Current medications',
  'appointments': 'Appointment history',
  'emergencyInformation': 'Emergency information',
};

const List<String> _structuredDataOrder = [
  'profile',
  'allergies',
  'conditions',
  'medications',
  'emergencyInformation',
  'appointments',
];

class _SessionApprovalScreenState extends State<SessionApprovalScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int _sessionDurationMinutes = 20;

  final List<_CategoryState> _categories = [];
  final Set<String> _structuredDataSelected = <String>{};
  bool _allowDownload = false;
  bool _allowUpload = true;
  bool _saveAsDefault = false;

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
    final preview = await ApiService.fetchApprovalPreview(widget.sessionId);
    if (!mounted) return;
    if (preview == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load sharing options. Please try again.';
      });
      return;
    }

    _categories.clear();
    final categoriesRaw = preview['categories'];
    if (categoriesRaw is List) {
      for (final entry in categoriesRaw) {
        if (entry is! Map) continue;
        final documents = (entry['documents'] is List)
            ? List<Map<String, dynamic>>.from(
                (entry['documents'] as List).whereType<Map>().map(
                      (doc) => doc.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
              )
            : <Map<String, dynamic>>[];
        final category = _CategoryState(
          category: (entry['category'] ?? '').toString(),
          documentCount: int.tryParse((entry['documentCount'] ?? '0').toString()) ?? 0,
          documents: documents,
          defaultState: (entry['defaultState'] ?? 'ask').toString(),
        );
        final preselected = entry['preselectedDocumentIds'];
        if (preselected is List) {
          category.selectedIds.addAll(preselected.map((id) => id.toString()));
        }
        _categories.add(category);
      }
    }

    final structuredDefaults = preview['structuredDataDefaults'];
    if (structuredDefaults is Map) {
      for (final scope in _structuredDataOrder) {
        if (structuredDefaults[scope] == true) {
          _structuredDataSelected.add(scope);
        }
      }
    }

    final capabilityDefaults = preview['capabilityDefaults'];
    if (capabilityDefaults is Map) {
      _allowDownload = capabilityDefaults['allowDoctorDownload'] == true;
      _allowUpload = capabilityDefaults['allowDoctorUploadToPatient'] != false;
    }

    setState(() {
      _sessionDurationMinutes =
          int.tryParse((preview['sessionDurationMinutes'] ?? '20').toString()) ?? 20;
      _loading = false;
    });
  }

  int get _totalDocumentCount =>
      _categories.fold(0, (sum, c) => sum + c.documentCount);
  int get _totalSelectedCount =>
      _categories.fold(0, (sum, c) => sum + c.selectedIds.length);

  void _toggleCategorySelectAll(_CategoryState category) {
    setState(() {
      if (category.selectedIds.length == category.documents.length) {
        category.selectedIds.clear();
      } else {
        category.selectedIds
          ..clear()
          ..addAll(category.documents.map((doc) => doc['id'].toString()));
      }
    });
  }

  Future<void> _submit({required bool approve}) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    if (!approve) {
      final response = await ApiService.respondToSessionRequest(
        sessionId: widget.sessionId,
        status: 'declined',
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop(response['success'] == true ? 'declined' : null);
      return;
    }

    final selectedDocumentIds = <String>[];
    final selectedCategories = <String>[];
    for (final category in _categories) {
      if (category.selectedIds.isNotEmpty) {
        selectedCategories.add(category.category);
        selectedDocumentIds.addAll(category.selectedIds);
      }
    }

    final response = await ApiService.respondToSessionRequest(
      sessionId: widget.sessionId,
      status: 'accepted',
      selection: {
        'selectedDocumentIds': selectedDocumentIds,
        'selectedCategories': selectedCategories,
        'structuredDataScopes': _structuredDataSelected.toList(),
        'capabilities': {
          'allowDoctorDownload': _allowDownload,
          'allowDoctorUploadToPatient': _allowUpload,
        },
        if (_saveAsDefault) 'saveAsDefault': true,
        if (_saveAsDefault)
          'categoryDefaultsToSave': {
            for (final category in _categories)
              category.category: category.selectedIds.isEmpty
                  ? 'deny'
                  : (category.selectedIds.length == category.documents.length
                      ? 'share'
                      : 'ask'),
          },
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response['success'] == true) {
      Navigator.of(context).pop('accepted');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Could not approve this request.',
          ),
        ),
      );
    }
  }

  Future<void> _showSummaryAndConfirm() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final selectedCategoryLines = _categories
            .where((c) => c.selectedIds.isNotEmpty)
            .map((c) => '${c.selectedIds.length} ${c.category}${c.selectedIds.length == 1 ? '' : 's'}');
        final structuredLines = _structuredDataSelected
            .map((scope) => _structuredDataLabels[scope] ?? scope);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are sharing:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface),
                ),
                const SizedBox(height: 12),
                if (selectedCategoryLines.isEmpty && structuredLines.isEmpty)
                  Text('Nothing selected yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ...selectedCategoryLines.map((line) => _bullet(line, scheme)),
                if (structuredLines.isNotEmpty)
                  _bullet(structuredLines.join(', '), scheme),
                _bullet(
                  _allowUpload ? 'Doctor may upload documents' : 'Doctor may not upload documents',
                  scheme,
                ),
                _bullet(
                  _allowDownload ? 'Doctor may download shared files' : 'Doctor may not download shared files',
                  scheme,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Review again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Confirm & Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true) {
      await _submit(approve: true);
    }
  }

  Widget _bullet(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
            Expanded(child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Review Access Request')),
      body: SafeArea(
        child: _loading
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
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          children: [
                            _buildDoctorHeader(scheme),
                            const SizedBox(height: 16),
                            _buildExplanationBanner(scheme),
                            const SizedBox(height: 20),
                            Text(
                              'Documents ($_totalSelectedCount of $_totalDocumentCount selected)',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            ..._categories.map(_buildCategoryCard),
                            const SizedBox(height: 20),
                            Text(
                              'Health information',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            _buildStructuredDataCard(scheme),
                            const SizedBox(height: 20),
                            Text(
                              'Doctor capabilities',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            _buildCapabilitiesCard(scheme),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _saveAsDefault,
                              onChanged: (value) => setState(() => _saveAsDefault = value ?? false),
                              title: const Text('Save these choices as my default'),
                              subtitle: Text(
                                'Future requests will start pre-filled with this selection.',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildActionBar(scheme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDoctorHeader(ColorScheme scheme) {
    final avatarUrl = ApiService.resolveMediaUrl(widget.doctorAvatarUrl) ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty ? const Icon(Icons.medical_services_rounded) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctorName.isEmpty ? 'Doctor' : widget.doctorName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                if (widget.doctorSpecialization?.isNotEmpty == true)
                  Text(
                    widget.doctorSpecialization!,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Requesting $_sessionDurationMinutes minutes of access',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only the items you select below will be shared with this doctor for this session. Nothing else in your vault is visible to them.',
              style: TextStyle(color: scheme.onSurface, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_CategoryState category) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allSelected = category.documents.isNotEmpty &&
        category.selectedIds.length == category.documents.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: category.documents.isEmpty
                ? null
                : () => setState(() => category.expanded = !category.expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.category,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.documentCount == 0
                              ? 'No documents in this category'
                              : '${category.selectedIds.length} of ${category.documentCount} selected',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (category.documents.isNotEmpty) ...[
                    TextButton(
                      onPressed: () => _toggleCategorySelectAll(category),
                      child: Text(allSelected ? 'Clear all' : 'Select all'),
                    ),
                    Icon(
                      category.expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (category.expanded && category.documents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Column(
                children: category.documents.map((doc) {
                  final id = doc['id'].toString();
                  final title = (doc['title'] ?? 'Document').toString();
                  final createdAt = doc['createdAt']?.toString() ?? '';
                  final dateLabel = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: category.selectedIds.contains(id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          category.selectedIds.add(id);
                        } else {
                          category.selectedIds.remove(id);
                        }
                      });
                    },
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: dateLabel.isEmpty ? null : Text(dateLabel, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStructuredDataCard(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: _structuredDataOrder.map((scope) {
          final label = _structuredDataLabels[scope] ?? scope;
          return CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _structuredDataSelected.contains(scope),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _structuredDataSelected.add(scope);
                } else {
                  _structuredDataSelected.remove(scope);
                }
              });
            },
            title: Text(label),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildCapabilitiesCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _allowDownload,
            onChanged: (value) => setState(() => _allowDownload = value),
            title: const Text('Allow file downloads'),
            subtitle: Text(
              'The doctor may save a copy of documents shared during this session.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _allowUpload,
            onChanged: (value) => setState(() => _allowUpload = value),
            title: const Text('Allow doctor uploads'),
            subtitle: Text(
              'The doctor may add prescriptions, reports or other files to your Medical Vault during this session.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _submit(approve: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Deny'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _submitting ? null : _showSummaryAndConfirm,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Approve Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
