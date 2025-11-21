import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = [
      l10n.t('termsOfService.intro'),
      l10n.t('termsOfService.section1'),
      l10n.t('termsOfService.section2'),
      l10n.t('termsOfService.section3'),
      l10n.t('termsOfService.section4'),
      l10n.t('termsOfService.section5'),
      l10n.t('termsOfService.section6'),
      l10n.t('termsOfService.section7'),
      l10n.t('termsOfService.section8'),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.t('termsOfService.title')),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  sections.join('\n\n'),
                  style: const TextStyle(fontSize: 16.0, height: 1.5),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.t('termsOfService.accept')),
              ),
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.all(16.0),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: ElevatedButton(
          //           onPressed: () => Navigator.pop(context),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.blue,
          //             foregroundColor: Colors.white,
          //           ),
          //           child: const Text('Accept'),
          //         ),
          //       ),
          //       const SizedBox(width: 16.0),
          //       // Expanded(
          //       //   child: OutlinedButton(
          //       //     onPressed: () => Navigator.pop(context),
          //       //     style: OutlinedButton.styleFrom(
          //       //       foregroundColor: Colors.blue,
          //       //       side: const BorderSide(color: Colors.green),
          //       //     ),
          //       //     child: const Text('Decline'),
          //       //   ),
          //       // ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}