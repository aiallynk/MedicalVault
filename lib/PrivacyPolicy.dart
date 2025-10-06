import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Information We Collect',
              'We collect information you provide directly to us, such as when you create an account, upload medical documents, or contact us for support. This may include:\n\n'
                  '• Personal Information: Name, email address, phone number\n'
                  '• Medical Information: Medical records, prescriptions, lab reports, insurance documents\n'
                  '• Account Information: Username, password, profile information\n'
                  '• Usage Information: How you interact with our application',
            ),
            _buildSection(
              context,
              '2. How We Use Your Information',
              'We use the information we collect to:\n\n'
                  '• Provide, maintain, and improve our services\n'
                  '• Process transactions and send related information\n'
                  '• Send technical notices, updates, security alerts, and support messages\n'
                  '• Respond to your comments, questions, and provide customer service\n'
                  '• Monitor and analyze trends, usage, and activities in connection with our services',
            ),
            _buildSection(
              context,
              '3. Information Sharing and Disclosure',
              'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except in the following circumstances:\n\n'
                  '• With your explicit consent\n'
                  '• To comply with legal obligations\n'
                  '• To protect our rights, privacy, safety, or property\n'
                  '• In connection with a merger, acquisition, or sale of assets\n'
                  '• With healthcare providers when you authorize sharing',
            ),
            _buildSection(
              context,
              '4. Data Security',
              'We implement appropriate security measures to protect your personal and medical information:\n\n'
                  '• Encryption of data in transit and at rest\n'
                  '• Secure authentication and access controls\n'
                  '• Regular security audits and updates\n'
                  '• Limited access to personal information on a need-to-know basis\n'
                  '• Secure data centers with physical security measures',
            ),
            _buildSection(
              context,
              '5. Health Information Protection',
              'Your medical information is protected under strict privacy standards:\n\n'
                  '• All health data is encrypted using industry-standard encryption\n'
                  '• Access to medical records is logged and monitored\n'
                  '• We comply with applicable health privacy regulations\n'
                  '• Medical information is only shared with your explicit authorization',
            ),
            _buildSection(
              context,
              '6. Data Retention',
              'We retain your information for as long as your account is active or as needed to provide you services. We may retain certain information for longer periods as required by law or for legitimate business purposes.',
            ),
            _buildSection(
              context,
              '7. Your Rights and Choices',
              'You have the right to:\n\n'
                  '• Access your personal information\n'
                  '• Correct inaccurate or incomplete information\n'
                  '• Delete your account and associated data\n'
                  '• Export your medical records\n'
                  '• Withdraw consent for data processing\n'
                  '• Opt out of certain communications',
            ),
            _buildSection(
              context,
              '8. Cookies and Tracking Technologies',
              'We use cookies and similar tracking technologies to enhance your experience:\n\n'
                  '• Essential cookies for app functionality\n'
                  '• Analytics cookies to understand usage patterns\n'
                  '• Security cookies to protect against fraud\n'
                  '• You can control cookie settings through your device preferences',
            ),
            _buildSection(
              context,
              '9. Third-Party Services',
              'Our application may integrate with third-party services for enhanced functionality:\n\n'
                  '• Cloud storage providers for secure data storage\n'
                  '• Analytics services for app improvement\n'
                  '• Payment processors for premium features\n'
                  '• All third-party integrations comply with our privacy standards',
            ),
            _buildSection(
              context,
              '10. Children\'s Privacy',
              'Our services are not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.',
            ),
            _buildSection(
              context,
              '11. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your own. We ensure that such transfers comply with applicable data protection laws and implement appropriate safeguards.',
            ),
            _buildSection(
              context,
              '12. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. We encourage you to review this Privacy Policy periodically.',
            ),
            _buildSection(
              context,
              '13. Contact Us',
              'If you have any questions about this Privacy Policy or our privacy practices, please contact us at:\n\n'
                  'Email: privacy@medicalvault.com\n'
                  'Phone: +1 (555) 123-4567\n'
                  'Address: 123 Medical Plaza, Health City, HC 12345\n\n'
                  'Data Protection Officer: dpo@medicalvault.com',
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use Medical Vault.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
