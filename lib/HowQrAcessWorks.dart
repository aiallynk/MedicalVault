import 'package:flutter/material.dart';
import 'package:hello/localization/app_localizations.dart';

class QrAccessWorks extends StatelessWidget {
  const QrAccessWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('qrAccess.title'),
          style: theme.textTheme.titleLarge,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('qrAccess.heading'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('qrAccess.intro'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),

            // Step 1
            Text(
              l10n.t('qrAccess.step1.title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('qrAccess.step1.body'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Step 2
            Text(
              l10n.t('qrAccess.step2.title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('qrAccess.step2.body'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Step 3
            Text(
              l10n.t('qrAccess.step3.title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('qrAccess.step3.body'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Step 4
            Text(
              l10n.t('qrAccess.step4.title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('qrAccess.step4.body'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            Text(
              l10n.t('qrAccess.summary'),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
