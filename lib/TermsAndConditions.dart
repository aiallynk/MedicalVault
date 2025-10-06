import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
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
              '1. Acceptance of Terms',
              'By accessing and using the Medical Vault application, you accept and agree to be bound by the terms and provision of this agreement.',
            ),
            _buildSection(
              context,
              '2. Use License',
              'Permission is granted to temporarily download one copy of Medical Vault per device for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.',
            ),
            _buildSection(
              context,
              '3. Medical Information Disclaimer',
              'The Medical Vault application is designed to help you store and organize your medical records. However, this application is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
            ),
            _buildSection(
              context,
              '4. Data Security and Privacy',
              'We are committed to protecting your personal and medical information. All data is encrypted and stored securely. We do not share your medical information with third parties without your explicit consent.',
            ),
            _buildSection(
              context,
              '5. User Responsibilities',
              'You are responsible for:\n'
                  '• Maintaining the accuracy of your medical information\n'
                  '• Keeping your login credentials secure\n'
                  '• Using the application in compliance with applicable laws\n'
                  '• Not sharing your account with others',
            ),
            _buildSection(
              context,
              '6. Prohibited Uses',
              'You may not use our application:\n'
                  '• For any unlawful purpose or to solicit others to perform unlawful acts\n'
                  '• To violate any international, federal, provincial, or state regulations, rules, laws, or local ordinances\n'
                  '• To infringe upon or violate our intellectual property rights or the intellectual property rights of others\n'
                  '• To harass, abuse, insult, harm, defame, slander, disparage, intimidate, or discriminate',
            ),
            _buildSection(
              context,
              '7. Content Accuracy',
              'We strive to provide accurate and up-to-date information, but we make no warranties about the completeness, reliability, and accuracy of any information or services provided through our application.',
            ),
            _buildSection(
              context,
              '8. Limitation of Liability',
              'In no event shall Medical Vault, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, punitive, consequential, or special damages arising out of or related to your use of the application.',
            ),
            _buildSection(
              context,
              '9. Termination',
              'We may terminate or suspend your account and bar access to the application immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever and without limitation, including but not limited to a breach of the Terms.',
            ),
            _buildSection(
              context,
              '10. Changes to Terms',
              'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect.',
            ),
            _buildSection(
              context,
              '11. Contact Information',
              'If you have any questions about these Terms and Conditions, please contact us at:\n\n'
                  'Email: support@medicalvault.com\n'
                  'Phone: +1 (555) 123-4567\n'
                  'Address: 123 Medical Plaza, Health City, HC 12345',
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
                'By using Medical Vault, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
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
