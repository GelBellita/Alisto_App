import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

// =========================================================
// HELP & SUPPORT SCREEN
// Ported from the web dashboard's Help & Support page
// (FAQ accordion, contact card, other help options, contact info row).
// =========================================================
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // TODO: replace with ALISTO's real support contact details.
  static const String supportPhone = '+63 32 000 0000';
  static const String supportEmail = 'alisto.support@uc.edu.ph';
  static const String supportAddress =
      'University of Cebu, College of Computer Studies\nCebu City, Philippines';

  static const List<_Faq> _faqs = [
    _Faq(
      question: 'Does ALISTO need internet to detect emergencies?',
      answer:
          'No. ALISTO processes configured emergency voice phrases offline. '
          'An internet or cellular connection is only needed afterward, to '
          'send the emergency SMS alert to registered contacts.',
    ),
    _Faq(
      question: 'What happens when an emergency phrase is detected?',
      answer:
          "ALISTO sends an SMS alert to the user's registered emergency "
          'contacts containing their name, the detected message, their '
          'registered address or location, and the date and time of the '
          'alert.',
    ),
    _Faq(
      question: 'What if the SMS alert fails to send?',
      answer:
          'Emergency SMS delivery requires a working cellular network, a '
          'valid SIM card, and enough battery on the paired device. If any '
          'of these are unavailable, delivery may be delayed or fail — keep '
          'the device charged and the SIM active at all times.',
    ),
    _Faq(
      question: 'Can ALISTO replace calling emergency services?',
      answer:
          'No. ALISTO is an additional means of requesting help, not a '
          'replacement for professional medical services or emergency '
          'responders. In a life-threatening situation, contact emergency '
          'services directly.',
    ),
    _Faq(
      question: 'How do I update my emergency contacts?',
      answer:
          'Go to My Loved Ones to add, edit, or remove the people who '
          'should receive alerts from this device.',
    ),
  ];

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Frequently Asked Questions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                "We're here to help you. Find answers below.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ..._faqs.map((faq) => _FaqTile(faq: faq)),
              const SizedBox(height: 18),

              // ---- Need more help? contact card ----
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.headset_mic_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Need more help?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "If you can't find the answer you're looking for, our "
                      'support team is ready to assist you.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: 'Contact Support',
                        onPressed: () => _copyToClipboard(
                          context,
                          supportEmail,
                          'Support email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We usually respond within 24 hours',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- Other ways to get help ----
              Text(
                'Other Ways to Get Help',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _HelpOptionCard(
                icon: Icons.menu_book_rounded,
                color: Accent.blue,
                title: 'User Guide',
                subtitle:
                    'Learn how to use Alisto with our step-by-step guide.',
              ),
              const SizedBox(height: 10),
              _HelpOptionCard(
                icon: Icons.report_problem_rounded,
                color: Accent.yellow,
                title: 'Report a Problem',
                subtitle: 'Found a problem? Let us know so we can fix it.',
              ),
              const SizedBox(height: 10),
              _HelpOptionCard(
                icon: Icons.info_rounded,
                color: Accent.purple,
                title: 'About Alisto',
                subtitle: 'Learn more about Alisto and its mission.',
              ),
              const SizedBox(height: 24),

              // ---- Contact information ----
              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ContactInfoTile(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: supportPhone,
                onTap: () =>
                    _copyToClipboard(context, supportPhone, 'Phone number'),
              ),
              const SizedBox(height: 10),
              _ContactInfoTile(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: supportEmail,
                onTap: () =>
                    _copyToClipboard(context, supportEmail, 'Email address'),
              ),
              const SizedBox(height: 10),
              _ContactInfoTile(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: supportAddress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq({required this.question, required this.answer});
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.faq.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 14, 14),
                child: Text(
                  widget.faq.answer,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 150),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpOptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _HelpOptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Coming soon'))),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _ContactInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
