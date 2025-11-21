import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  bool _hasAcceptedPrivacy = false;
  bool _isLoading = true;
  String _lastUpdated = '';
  String _version = '1.0';
  List<Map<String, dynamic>> _privacyUpdates = [];
  bool _showUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyStatus();
    _fetchPrivacyUpdates();
  }

  Future<void> _loadPrivacyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasAcceptedPrivacy = prefs.getBool('privacy_accepted') ?? false;
      _lastUpdated = prefs.getString('privacy_last_updated') ?? '2024-01-01';
      _version = prefs.getString('privacy_version') ?? '1.0';
      _isLoading = false;
    });
  }

  Future<void> _fetchPrivacyUpdates() async {
    try {
      // Simulate fetching privacy updates from server
      // In real implementation, this would be an API call
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _privacyUpdates = [
          {
            'dateKey': 'privacy.update1.date',
            'versionKey': 'privacy.update1.version',
            'changeKeys': [
              'privacy.update1.change1',
              'privacy.update1.change2',
              'privacy.update1.change3',
            ]
          },
          {
            'dateKey': 'privacy.update2.date',
            'versionKey': 'privacy.update2.version',
            'changeKeys': [
              'privacy.update2.change1',
              'privacy.update2.change2',
              'privacy.update2.change3',
            ]
          }
        ];
      });
    } catch (e) {
      print('Error fetching privacy updates: $e');
    }
  }

  Future<void> _acceptPrivacyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    await prefs.setString(
        'privacy_accepted_date', DateTime.now().toIso8601String());
    await prefs.setString('privacy_version', _version);

    setState(() {
      _hasAcceptedPrivacy = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(context.l10n.t('privacy.acceptedSuccess')),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = List.generate(
      13,
      (index) => index + 1,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.t('privacy.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () {
              setState(() {
                _showUpdates = !_showUpdates;
              });
            },
            tooltip: l10n.t('privacy.showUpdates'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Privacy Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _hasAcceptedPrivacy
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(
                        _hasAcceptedPrivacy
                            ? Icons.check_circle
                            : Icons.warning,
                        color:
                            _hasAcceptedPrivacy ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasAcceptedPrivacy
                              ? l10n.format('privacy.banner.accepted',
                                  {'version': _version})
                              : l10n.t('privacy.banner.pending'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _hasAcceptedPrivacy
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Privacy Updates Section
                if (_showUpdates) _buildPrivacyUpdatesSection(l10n),

                // Main Privacy Policy Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final sectionIndex in sections)
                            _buildSectionBlock(
                              context,
                              l10n,
                              sectionIndex,
                            ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('privacyPage.summary'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.info,
                                        color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.format('privacyPage.lastUpdated',
                                          {'date': _lastUpdated}),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.format('privacy.versionLabel',
                                      {'version': _version}),
                                  style: TextStyle(color: Colors.blue.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (!_hasAcceptedPrivacy) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _acceptPrivacyPolicy,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(l10n.t('privacy.acceptButton')),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(_hasAcceptedPrivacy
                              ? l10n.t('common.close')
                              : l10n.t('privacy.understandButton')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildPrivacyUpdatesSection(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                l10n.t('privacy.updatesTitle'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._privacyUpdates
              .map((update) => _buildUpdateItem(update, l10n)),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(
      Map<String, dynamic> update, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.format('privacy.update.versionLabel',
                    {'version': l10n.t(update['versionKey'])}),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                l10n.t(update['dateKey']),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(update['changeKeys'] as List).map((key) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.grey)),
                    Expanded(
                      child: Text(
                        l10n.t(key as String),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSectionBlock(
      BuildContext context, AppLocalizations l10n, int index) {
    final title = l10n.t('privacyPage.section$index.title');
    final body = l10n.t('privacyPage.section$index.body');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
