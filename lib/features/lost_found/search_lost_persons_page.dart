import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api_service.dart';
import 'lost_found_report_page.dart';
import 'lost_person_photo.dart';
import 'lost_person_detail_page.dart';

class SearchLostPersonsPage extends StatefulWidget {
  const SearchLostPersonsPage({
    super.key,
    required this.currentUser,
    required this.linkedProfiles,
  });

  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> linkedProfiles;

  @override
  State<SearchLostPersonsPage> createState() => _SearchLostPersonsPageState();
}

class _SearchLostPersonsPageState extends State<SearchLostPersonsPage> {
  static const int _maxPhotoSearchBytes = 4 * 1024 * 1024;

  final _queryController = TextEditingController();
  final _ageController = TextEditingController();
  final _areaController = TextEditingController();
  final _picker = ImagePicker();

  String _gender = '';
  double _radiusKm = 10;
  bool _loading = false;
  String _message = '';
  List<Map<String, dynamic>> _results = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _ageController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final results = await ApiService.searchLostPersons(
        query: _queryController.text,
        age: int.tryParse(_ageController.text.trim()),
        gender: _gender,
        location: _areaController.text,
        radiusKm: _radiusKm,
      );
      if (!mounted) return;
      setState(() {
        _results = results
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
        if (_results.isEmpty) {
          _message = 'No active lost-person reports matched your search.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchWithPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final photo = File(picked.path);
    final photoSize = await photo.length();
    if (photoSize > _maxPhotoSearchBytes) {
      if (!mounted) return;
      setState(() {
        _message = 'Photo is too large. Please choose a JPG or PNG under 4 MB.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final response = await ApiService.searchLostPersonsWithPhoto(
        photo: photo,
        query: _queryController.text,
        age: int.tryParse(_ageController.text.trim()),
        gender: _gender,
        location: _areaController.text,
        radiusKm: _radiusKm,
      );
      final data = response['data'];
      final rawResults = data is Map ? data['results'] : const [];
      final photoSearch = data is Map ? data['photoSearch'] : null;
      final photoMessage =
          photoSearch is Map ? photoSearch['message']?.toString() : null;
      if (!mounted) return;
      setState(() {
        _results = rawResults is List
            ? rawResults
                .whereType<Map>()
                .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
                .toList(growable: false)
            : const [];
        _message = photoMessage ??
            'Photo-assisted search completed. Face matching is not enabled yet.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(Map<String, dynamic> report) {
    final id = report['id']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LostPersonDetailPage(
          reportId: id,
          currentUser: widget.currentUser,
          linkedProfiles: widget.linkedProfiles,
        ),
      ),
    );
  }

  void _openFoundReport(Map<String, dynamic> report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LostFoundReportPage(
          currentUser: widget.currentUser,
          linkedProfiles: widget.linkedProfiles,
          initialMode: LostFoundReportMode.found,
          relatedLostReportId: report['id']?.toString(),
        ),
      ),
    );
  }

  String _value(Map<String, dynamic> report, String key,
      [String fallback = '']) {
    final value = report[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Lost Persons'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Search by missing person name',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Approx age'),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Any')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setState(() => _gender = value ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Last seen area',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '${_radiusKm.toStringAsFixed(0)} km',
                      onChanged: (value) => setState(() => _radiusKm = value),
                    ),
                  ),
                  Text('${_radiusKm.toStringAsFixed(0)} km'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _searchWithPhoto,
                    icon: const Icon(Icons.photo_camera_back_rounded),
                    label: const Text('Search with photo'),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              for (final report in _results)
                _ResultCard(
                  report: report,
                  onView: () => _openDetail(report),
                  onFound: () => _openFoundReport(report),
                  value: _value,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.report,
    required this.onView,
    required this.onFound,
    required this.value,
  });

  final Map<String, dynamic> report;
  final VoidCallback onView;
  final VoidCallback onFound;
  final String Function(Map<String, dynamic>, String, [String]) value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = value(report, 'photoUrl');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LostPersonPhoto(
              photoUrl: photoUrl,
              width: 74,
              height: 88,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value(report, 'personName', 'Unnamed person'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      'Age ${value(report, 'approxAge', 'unknown')}',
                      value(report, 'gender', 'Unknown'),
                      value(report, 'status', 'open'),
                    ].join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value(
                        report, 'lastSeenLocationText', 'Location not shared'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: onView,
                        child: const Text('View details'),
                      ),
                      OutlinedButton(
                        onPressed: onFound,
                        child: const Text('I found this person'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
