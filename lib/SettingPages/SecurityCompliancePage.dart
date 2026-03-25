import 'package:flutter/material.dart';

class SecurityCompliancePage extends StatelessWidget {
  const SecurityCompliancePage({super.key});

  static const Color _pageBackground = Color(0xFFFFFFFF);
  static const Color _cardBackground = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFE5E7EB);
  static const Color _titleColor = Color(0xFF111827);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _Header(
              title: 'Security & Compliance',
              subtitle:
                  'Clear, human-friendly information about how your records stay safe.',
            ),
            const SizedBox(height: 18),
            const _SectionCard(
              title: 'What this means for you',
              child: Column(
                children: [
                  _TrustRow(
                    icon: Icons.lock_outline_rounded,
                    iconColor: Color(0xFF0EA5A4),
                    title: 'Data is encrypted',
                    description:
                        'Sensitive information is protected while stored and while moving between services.',
                  ),
                  Divider(height: 24, color: _cardBorder),
                  _TrustRow(
                    icon: Icons.visibility_off_outlined,
                    iconColor: Color(0xFF3B82F6),
                    title: 'Records stay private',
                    description:
                        'Access is limited so only the right people and approved actions can reach your records.',
                  ),
                  Divider(height: 24, color: _cardBorder),
                  _TrustRow(
                    icon: Icons.health_and_safety_outlined,
                    iconColor: Color(0xFF14B8A6),
                    title: 'Healthcare safety practices',
                    description:
                        'The app follows careful handling practices designed for health information and patient trust.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Need technical detail?',
              subtitle:
                  'You can view a short technical summary of the protections used in the app.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showTechnicalDetail(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFFEAF4FF),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Learn More',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTechnicalDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Technical Detail',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'A short overview of the safeguards supporting your records.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: _subtitleColor,
                  ),
                ),
                SizedBox(height: 18),
                _DetailPoint(
                  title: 'Encrypted storage and transfer',
                  description:
                      'Sensitive data is protected both at rest and while being sent across the network.',
                ),
                SizedBox(height: 12),
                _DetailPoint(
                  title: 'Controlled access',
                  description:
                      'Sessions, roles, and account protections help keep access limited and traceable.',
                ),
                SizedBox(height: 12),
                _DetailPoint(
                  title: 'Operational safeguards',
                  description:
                      'Validation, monitoring, and secure handling practices reduce misuse and support audit readiness.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SecurityCompliancePage._titleColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SecurityCompliancePage._subtitleColor,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SecurityCompliancePage._cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SecurityCompliancePage._cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SecurityCompliancePage._titleColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SecurityCompliancePage._subtitleColor,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _TrustRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: SecurityCompliancePage._titleColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SecurityCompliancePage._subtitleColor,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFEFFCF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF16A34A),
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _DetailPoint extends StatelessWidget {
  final String title;
  final String description;

  const _DetailPoint({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SecurityCompliancePage._titleColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SecurityCompliancePage._subtitleColor,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
