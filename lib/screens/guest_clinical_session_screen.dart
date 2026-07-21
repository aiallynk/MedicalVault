import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';

import '../api_service.dart';

/// Patient-only creation flow.  The API accepts no implied document scope:
/// every category begins off and individual document selection can be added
/// from the vault before this call without widening this screen's defaults.
class GuestClinicalSessionScreen extends StatefulWidget {
  const GuestClinicalSessionScreen({super.key});

  @override
  State<GuestClinicalSessionScreen> createState() => _GuestClinicalSessionScreenState();
}

class _GuestClinicalSessionScreenState extends State<GuestClinicalSessionScreen> {
  static const categories = <String>['Report', 'Prescription', 'Bill', 'Insurance', 'medicines', 'allergies', 'conditions', 'appointments', 'emergency'];
  final selected = <String>{};
  bool downloads = false;
  bool chat = true;
  bool notes = false;
  bool uploads = false;
  bool creating = false;
  Map<String, dynamic>? invitation;
  Map<String, dynamic>? session;
  Timer? poller;

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => creating = true);
    final result = await ApiService.createGuestClinicalSession(
      dataCategories: selected.toList(growable: false),
      permissions: {'canDownload': downloads, 'canChat': chat, 'canAddNotes': notes, 'canUpload': uploads},
    );
    if (!mounted) return;
    setState(() {
      creating = false;
      invitation = result?['invitation'] is Map ? Map<String, dynamic>.from(result!['invitation']) : null;
      session = result?['session'] is Map ? Map<String, dynamic>.from(result!['session']) : null;
    });
    if (session?['id'] != null) {
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 5), (_) => _refreshSession());
    }
    if (invitation == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create the guest session. Please try again.')));
  }

  Future<void> _refreshSession() async {
    final id = session?['id']?.toString();
    if (id == null || id.isEmpty) return;
    final updated = await ApiService.fetchGuestClinicalSession(id);
    if (mounted && updated != null) setState(() => session = updated);
  }

  Future<void> _approve() async {
    final id = session?['id']?.toString();
    if (id == null) return;
    final result = await ApiService.approveGuestClinicalSession(id);
    if (mounted && result?['session'] is Map) setState(() => session = Map<String, dynamic>.from(result!['session']));
  }

  @override
  Widget build(BuildContext context) {
    if (invitation != null) {
      final code = invitation!['joinCode']?.toString() ?? '';
      final link = invitation!['guestUrl']?.toString() ?? '';
      return Scaffold(appBar: AppBar(title: const Text('Guest session invitation')), body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.hourglass_top_rounded, size: 52), const SizedBox(height: 16),
        const Text('Waiting for guest', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        const Text('Share the code or secure link only with the intended healthcare professional. They cannot see any records until you review and approve their request.', textAlign: TextAlign.center), const SizedBox(height: 24),
        Card(child: ListTile(title: const Text('One-time session code'), subtitle: Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: code))))),
        Card(child: ListTile(title: const Text('Secure invitation link'), subtitle: Text(link, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: link))))),
        if (link.isNotEmpty) Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Guest QR code'), const SizedBox(height: 12),
              QrImageView(data: link, size: 180, errorCorrectionLevel: QrErrorCorrectLevel.M),
            ]),
          ),
        ),
        const SizedBox(height: 12), const Text('Identity warning: Medical Vault may not have verified this person as a registered doctor. Email verification only proves control of their email address.'),
        if (session?['status'] == 'patient_review_required') ...[
          const SizedBox(height: 20),
          const Text('Guest approval required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text('${(session?['guest'] as Map?)?['claimedName'] ?? 'Guest'} — ${(session?['guest'] as Map?)?['verificationLabel'] ?? 'Identity not verified'}'),
          const SizedBox(height: 8),
          const Text('Review the guest’s claimed details carefully. Network evidence is not identity proof.'),
          FilledButton(onPressed: _approve, child: const Text('Approve this guest')),
        ],
        if (session?['status'] == 'approved' || session?['status'] == 'active') ...[
          const SizedBox(height: 20),
          const Text('Guest session is active. You can revoke access at any time from this screen.', style: TextStyle(fontWeight: FontWeight.bold)),
          OutlinedButton(onPressed: () => ApiService.endGuestClinicalSession(session!['id'].toString(), revoke: true).then((_) => _refreshSession()), child: const Text('Revoke guest access')),
        ],
      ]));
    }
    return Scaffold(appBar: AppBar(title: const Text('Start Guest Clinical Session')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('This access is intended for a healthcare professional who does not have a Medical Vault account. Review their details carefully before granting access.', style: TextStyle(fontSize: 16)), const SizedBox(height: 22),
      const Text('Data to offer for your review', style: TextStyle(fontWeight: FontWeight.bold)), const Text('Nothing is shared by default. You will approve the guest before any selected data becomes available.'),
      ...categories.map((category) => CheckboxListTile(value: selected.contains(category), onChanged: (value) => setState(() => value == true ? selected.add(category) : selected.remove(category)), title: Text(category))),
      const Divider(), SwitchListTile(value: downloads, onChanged: (v) => setState(() => downloads = v), title: const Text('Permit downloads'), subtitle: const Text('Off by default')),
      SwitchListTile(value: chat, onChanged: (v) => setState(() => chat = v), title: const Text('Permit chat')),
      SwitchListTile(value: notes, onChanged: (v) => setState(() => notes = v), title: const Text('Permit guest notes')),
      SwitchListTile(value: uploads, onChanged: (v) => setState(() => uploads = v), title: const Text('Permit guest document upload'), subtitle: const Text('Off by default')),
      const SizedBox(height: 18), FilledButton(onPressed: creating ? null : _create, child: creating ? const CircularProgressIndicator() : const Text('Create secure invitation')),
    ]));
  }
}
