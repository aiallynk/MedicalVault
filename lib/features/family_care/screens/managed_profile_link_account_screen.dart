import 'package:flutter/material.dart';

import '../data/family_care_api.dart';
import '../data/family_care_repository.dart';
import '../data/models/family_care_extensions.dart';

class ManagedProfileLinkAccountScreen extends StatefulWidget {
  const ManagedProfileLinkAccountScreen({super.key, required this.profileId, required this.relationship});
  final String profileId;
  final String relationship;

  @override
  State<ManagedProfileLinkAccountScreen> createState() => _ManagedProfileLinkAccountScreenState();
}

class _ManagedProfileLinkAccountScreenState extends State<ManagedProfileLinkAccountScreen> {
  final _repository = FamilyCareRepository();
  final _query = TextEditingController();
  List<FamilyUserSearchResult> _results = const [];
  FamilyUserSearchResult? _selected;
  bool _searching = false;
  bool _sending = false;

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() { _searching = true; _results = const []; _selected = null; });
    try {
      final results = await _repository.searchExistingUsers(_query.text.trim());
      if (mounted) setState(() => _results = results);
    } on FamilyCareApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally { if (mounted) setState(() => _searching = false); }
  }

  Future<void> _link() async {
    final selected = _selected;
    if (selected == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _repository.requestProfileLink(profileId: widget.profileId, targetUserId: selected.id, relationship: widget.relationship);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consent request sent. The profile is not linked until the account accepts.')));
        Navigator.pop(context, true);
      }
    } on FamilyCareApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Link Existing Account')),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Find the family member’s account and send a consent request. Existing records will never be auto-merged; conflicting data requires review.'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _query, decoration: const InputDecoration(labelText: 'Medical Vault ID, email, or phone', border: OutlineInputBorder()), onSubmitted: (_) => _search())),
            const SizedBox(width: 8),
            FilledButton(onPressed: _searching ? null : _search, child: const Text('Search')),
          ]),
          for (final result in _results) RadioListTile<FamilyUserSearchResult>(
            value: result,
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            title: Text(result.displayName),
            subtitle: Text([result.maskedEmail, result.maskedPhone].where((value) => value.isNotEmpty).join(' • ')),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _selected == null || _sending ? null : _link, icon: const Icon(Icons.link), label: Text(_sending ? 'Sending…' : 'Send consent request')),
        ])),
      );
}
