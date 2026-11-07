import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/care_plan_models.dart';
import '../services/care_plan_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

// =========================================================
// SHARED: loads the plan, the subscription and this account's payments
// once, and hands the combined result to [builder].
// =========================================================
class _CarePlanData extends StatefulWidget {
  final String elderId;
  final Widget Function(
    BuildContext context,
    CarePlanInfo plan,
    PlanState state,
    List<PaymentRecord> payments,
  )
  builder;
  const _CarePlanData({required this.elderId, required this.builder});

  @override
  State<_CarePlanData> createState() => _CarePlanDataState();
}

class _CarePlanDataState extends State<_CarePlanData> {
  late final Stream<CarePlanInfo> _plan = CarePlanService.planStream();
  late final Stream<Map<String, dynamic>?> _sub =
      CarePlanService.subscriptionStream(widget.elderId);
  late final Stream<List<PaymentRecord>> _payments =
      CarePlanService.myPaymentsStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CarePlanInfo>(
      stream: _plan,
      initialData: CarePlanInfo.defaults,
      builder: (context, planSnap) {
        final plan = planSnap.data ?? CarePlanInfo.defaults;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _sub,
          builder: (context, subSnap) {
            if (subSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return StreamBuilder<List<PaymentRecord>>(
              stream: _payments,
              initialData: const <PaymentRecord>[],
              builder: (context, paySnap) {
                final payments = paySnap.data ?? const <PaymentRecord>[];
                final state = computePlanState(
                  sub: subSnap.data,
                  hasPending: payments.any((p) => p.isPending),
                );
                return widget.builder(context, plan, state, payments);
              },
            );
          },
        );
      },
    );
  }
}

Color _statusColor(PlanStatus status) {
  switch (status) {
    case PlanStatus.active:
      return Accent.green;
    case PlanStatus.expiring:
      return Accent.yellow;
    case PlanStatus.expired:
      return AppColors.error;
    case PlanStatus.pending:
      return AppColors.primary;
    case PlanStatus.none:
      return AppColors.textSecondary;
  }
}

Color _paymentColor(PaymentRecord p) =>
    p.isApproved ? Accent.green : (p.isRejected ? AppColors.error : Accent.yellow);

String _paymentLabel(PaymentRecord p) =>
    p.isApproved ? 'Approved' : (p.isRejected ? 'Rejected' : 'Pending');

// =========================================================
// CARE PLAN — status, what's included, pay, payment history
// =========================================================
class CarePlanScreen extends StatefulWidget {
  const CarePlanScreen({super.key});

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  // Held in State: a future created inside build() would restart on every
  // rebuild and flash the spinner.
  late final Future<String> _elder = FirestoreService.elderIdForCurrentUser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const MinimalBackAppBar(title: 'Care Plan'),
      body: ResponsiveContent(
        child: FutureBuilder<String>(
          future: _elder,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return const _Centered(
                icon: Icons.link_off_rounded,
                text:
                    'Register your Alisto device first. The care plan belongs '
                    'to the device you protect.',
              );
            }
            final elderId = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _CarePlanData(
                elderId: elderId,
                builder: (context, plan, state, payments) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusCard(plan: plan, state: state),
                    const SizedBox(height: 12),
                    if (payments.any((p) => p.isPending))
                      PendingPaymentNotice(
                        count: payments.where((p) => p.isPending).length,
                      ),
                    if (latestRejection(payments) case final rejected?)
                      _RejectionBanner(payment: rejected),
                    PrimaryButton(
                      label: state.status == PlanStatus.none ||
                              state.status == PlanStatus.pending
                          ? 'Subscribe with GCash'
                          : 'Renew with GCash',
                      onPressed: () => context.pushScreen(
                        PayCarePlanScreen(elderId: elderId),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Right under the button, where a family looks after paying.
                    const SectionLabel('Payment history'),
                    const SizedBox(height: 10),
                    // The history lists Pending and Approved payments only. A
                    // rejected one isn't listed; the red banner above tells
                    // the family what to fix instead.
                    if (payments.where((p) => !p.isRejected).isEmpty)
                      const AppCard(
                        child: Text(
                          'No payments yet. Your payments and their approval '
                          'status will appear here.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      )
                    else
                      for (final p in payments.where((p) => !p.isRejected)) ...[
                        PaymentTile(payment: p),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 14),
                    const SectionLabel("What's included"),
                    const SizedBox(height: 10),
                    const _BenefitsCard(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Centered({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CarePlanInfo plan;
  final PlanState state;
  const _StatusCard({required this.plan, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(state.status);
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: color.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              StatusPill(label: state.label, color: color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            state.headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              color: color == AppColors.textSecondary
                  ? AppColors.textPrimary
                  : color,
            ),
          ),
          if (state.paidUntil != '—') ...[
            const SizedBox(height: 4),
            Text(
              state.status == PlanStatus.expired
                  ? 'Ended ${state.paidUntil}'
                  : 'Paid until ${state.paidUntil}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPeso(plan.price),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'per month',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  final PaymentRecord payment;
  const _RejectionBanner({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppColors.error.withOpacity(0.06),
        borderColor: AppColors.error.withOpacity(0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your last payment was rejected'
              '${payment.rejectReason.isEmpty ? '' : ': ${payment.rejectReason}'}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
            if (payment.adminNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                payment.adminNote,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${payment.paymentNo} · ${planLengthText(payment.months)}. '
              'Please fix it and submit again.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static const _items = <(IconData, String, String)>[
    (
      Icons.sms_rounded,
      'Emergency SMS alerts',
      'Texts to your family and the barangay health worker when Alisto '
          'is triggered. ALISTO covers the SMS load.',
    ),
    (
      Icons.location_on_rounded,
      'Live location and app alerts',
      'See where the device is and get emergency notifications on your phone.',
    ),
    (
      Icons.medication_rounded,
      'Medicine reminders',
      'The device speaks the reminders at the times you set.',
    ),
    (
      Icons.build_rounded,
      'Maintenance and support',
      'Troubleshooting and check-ups for your Alisto device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, text) in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_rounded, size: 16, color: Accent.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency alerts keep working even if your plan expires. '
                  'Your safety always comes first.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// One payment in the history: an icon, a status pill, and a sentence saying
/// what the status means for the family.
class PaymentTile extends StatelessWidget {
  final PaymentRecord payment;
  const PaymentTile({super.key, required this.payment});

  IconData get _icon => payment.isApproved
      ? Icons.check_circle_rounded
      : (payment.isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

  String get _message {
    if (payment.isApproved) {
      return payment.periodEnd == null
          ? 'Approved. Your care plan is extended.'
          : 'Approved. Your care plan is valid until '
              '${formatPlanDate(payment.periodEnd!)}.';
    }
    if (payment.isRejected) {
      final why = [payment.rejectReason, payment.adminNote]
          .where((t) => t.isNotEmpty)
          .join(' — ');
      return why.isEmpty ? 'Rejected. Please submit it again.' : 'Rejected: $why';
    }
    return 'Waiting for admin approval. This usually takes a day.';
  }

  @override
  Widget build(BuildContext context) {
    final color = _paymentColor(payment);
    final date = payment.createdAt == null
        ? 'Sending…'
        : formatPlanDate(payment.createdAt!);
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withOpacity(0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${planLengthText(payment.months)} · ${formatPeso(payment.amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    StatusPill(label: _paymentLabel(payment), color: color),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment.paymentNo} · $date',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (payment.referenceNo.isNotEmpty)
                  Text(
                    'GCash ref ${payment.referenceNo}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: payment.isPending ? FontWeight.w500 : FontWeight.w600,
                    color: payment.isPending ? AppColors.textPrimary : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown near the top whenever a payment is waiting for the admin.
class PendingPaymentNotice extends StatelessWidget {
  final int count;
  const PendingPaymentNotice({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: Accent.yellow.withOpacity(0.10),
        borderColor: Accent.yellow.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Accent.yellow, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? 'Your payment is under review. We will update your plan '
                        'once the admin approves it.'
                    : '$count payments are under review. We will update your '
                        'plan once the admin approves them.',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// PAY — pick a plan length, scan the GCash QR, send the reference number
// =========================================================
class PayCarePlanScreen extends StatefulWidget {
  final String elderId;
  const PayCarePlanScreen({super.key, required this.elderId});

  @override
  State<PayCarePlanScreen> createState() => _PayCarePlanScreenState();
}

class _PayCarePlanScreenState extends State<PayCarePlanScreen> {
  final _payer = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final Stream<CarePlanInfo> _planStream = CarePlanService.planStream();
  late final Stream<Map<int, PlanQrInfo>> _qrStream = CarePlanService.qrStream();

  int _months = 1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _payer.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit(double unitPrice) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await CarePlanService.submitPayment(
        elderId: widget.elderId,
        months: _months,
        unitPrice: unitPrice,
        amountPaidText: _amount.text,
        referenceNo: _reference.text,
        payerName: _payer.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Accent.green),
      );
      Navigator.of(context).maybePop();
    } on CarePlanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const MinimalBackAppBar(title: 'Pay Care Plan'),
      body: ResponsiveContent(
        child: StreamBuilder<CarePlanInfo>(
          stream: _planStream,
          initialData: CarePlanInfo.defaults,
          builder: (context, planSnap) {
            final plan = planSnap.data ?? CarePlanInfo.defaults;
            return StreamBuilder<Map<int, PlanQrInfo>>(
              stream: _qrStream,
              initialData: planQrFromDoc(null),
              builder: (context, qrSnap) {
                final qr = (qrSnap.data ?? planQrFromDoc(null))[_months] ??
                    PlanQrInfo.defaults;
                return _buildForm(context, plan, qr);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, CarePlanInfo plan, PlanQrInfo qr) {
    final total = planTotal(plan.price, _months);
    final amount = parseAmount(_amount.text);
    final amountOk = amountMatches(amount, total);
    final refOk = isValidGcashReference(_reference.text);
    final nameOk = _payer.text.trim().length > 1;
    final canSubmit = amountOk && refOk && nameOk && !_submitting;

    String amountHint;
    Color amountColor = AppColors.textSecondary;
    if (_amount.text.trim().isEmpty || amount == null) {
      amountHint = 'Must be exactly ${formatPeso(total)} for ${planLengthText(_months)}.';
    } else if (amountOk) {
      amountHint = 'Matches your ${planLengthText(_months)} plan.';
      amountColor = Accent.green;
    } else {
      amountHint =
          '${formatPeso(amount)} doesn’t match ${planLengthText(_months)} '
          '(${formatPeso(total)}). Pick the plan that matches what you paid.';
      amountColor = const Color(0xFFB45309);
    }

    final refLength = _reference.text.length;
    final refHint = refLength > 0 && !refOk
        ? 'GCash reference numbers have 13 digits ($refLength/13).'
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan the QR, pay the exact amount, then enter your details.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Plan length'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final m in kPlanMonthOptions)
                  ButtonSegment(value: m, label: Text('$m mo')),
              ],
              selected: {_months},
              onSelectionChanged: (s) => setState(() {
                _months = s.first;
                _amount.clear(); // an old amount must not ride along to a new plan
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          _QrCard(qr: qr, total: total, months: _months),
          const SizedBox(height: 18),
          const _FieldLabel('Payer name'),
          _InputField(
            controller: _payer,
            hint: 'Name on GCash',
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Amount you sent'),
          _InputField(
            controller: _amount,
            hint: '0.00',
            prefixText: '₱ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() => _error = null),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(
              amountHint,
              style: TextStyle(fontSize: 12, color: amountColor),
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('GCash reference number'),
          _InputField(
            controller: _reference,
            hint: '13 digits, e.g. 1234567890123',
            keyboardType: TextInputType.number,
            maxLength: 13,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
          ),
          if (refHint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                refHint,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: amountOk
                ? 'Submit ${formatPeso(total)} payment'
                : 'Submit payment',
            loading: _submitting,
            onPressed: canSubmit ? () => _submit(plan.price) : null,
          ),
          const SizedBox(height: 10),
          const Text(
            'An admin checks your reference number against our GCash records '
            'and approves it, usually within a day. You will see the result '
            'on the Care Plan screen.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String> onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.prefixText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: formatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        counterText: '',
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final PlanQrInfo qr;
  final double total;
  final int months;
  const _QrCard({required this.qr, required this.total, required this.months});

  Widget _image() {
    final fallback = Image.asset(
      'assets/images/alisto_qr.jpg',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Center(
        child: Text(
          'QR not available yet.\nPlease contact support.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
      ),
    );
    final url = qr.qrImageUrl;
    String? network;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      network = url;
    } else if (url.startsWith('/') && kWebsiteBaseUrl.isNotEmpty) {
      network = '$kWebsiteBaseUrl$url';
    }
    if (network == null) return fallback;
    return Image.network(
      network,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _image(),
          ),
          const SizedBox(height: 12),
          Text(
            qr.gcashName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Text(
            'Or send to this GCash number',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (qr.gcashNumber.isNotEmpty)
            // The whole row is tappable. What gets copied is digits only, so
            // it pastes straight into GCash.
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                var copied = true;
                try {
                  await Clipboard.setData(
                    ClipboardData(text: gcashNumberForCopy(qr.gcashNumber)),
                  );
                } catch (_) {
                  copied = false; // never say "copied" if it wasn't
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      copied
                          ? 'GCash number copied. Paste it in GCash.'
                          : 'Could not copy. Please type ${qr.gcashNumber} in GCash.',
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        qr.gcashNumber,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Text(
              'No GCash number set yet. Please scan the QR code above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Send exactly',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  formatPeso(total),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'for ${planLengthText(months)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// HOME BANNER — only shows when the family should do something
// =========================================================
class CarePlanBanner extends StatefulWidget {
  const CarePlanBanner({super.key});

  @override
  State<CarePlanBanner> createState() => _CarePlanBannerState();
}

class _CarePlanBannerState extends State<CarePlanBanner> {
  late final Future<String> _elder = FirestoreService.elderIdForCurrentUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _elder,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return _CarePlanData(
          elderId: snap.data!,
          builder: (context, plan, state, payments) {
            final rejected = latestRejection(payments);
            final (String, String, IconData, Color)? content =
                _bannerContent(plan, state, rejected);
            if (content == null) return const SizedBox.shrink();
            final (title, text, icon, color) = content;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.pushScreen(const CarePlanScreen()),
                child: AppCard(
                  color: color.withOpacity(0.07),
                  borderColor: color.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              text,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
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
              ),
            );
          },
        );
      },
    );
  }

  (String, String, IconData, Color)? _bannerContent(
    CarePlanInfo plan,
    PlanState state,
    PaymentRecord? rejected,
  ) {
    if (rejected != null && state.status != PlanStatus.active) {
      return (
        'Payment rejected',
        rejected.rejectReason.isEmpty
            ? 'Tap to see why and send it again.'
            : '${rejected.rejectReason}. Tap to fix it.',
        Icons.error_outline_rounded,
        AppColors.error,
      );
    }
    switch (state.status) {
      case PlanStatus.pending:
        return (
          'Payment under review',
          'We are checking your GCash payment. This usually takes a day.',
          Icons.hourglass_top_rounded,
          AppColors.primary,
        );
      case PlanStatus.expiring:
        return (
          'Your care plan ends soon',
          '${state.headline.replaceFirst('Renews', 'Ends')}. '
              'Renew to keep SMS alerts and device support.',
          Icons.schedule_rounded,
          Accent.yellow,
        );
      case PlanStatus.expired:
        return (
          'Your care plan ${state.label == 'Cancelled' ? 'was cancelled' : 'has expired'}',
          'Renew to keep SMS alerts and device support. '
              'Emergency alerts keep working.',
          Icons.error_outline_rounded,
          AppColors.error,
        );
      case PlanStatus.none:
        return (
          'Get the Alisto Care Plan',
          'SMS alerts, maintenance and support from ${formatPeso(plan.price)} a month.',
          Icons.workspace_premium_rounded,
          AppColors.primary,
        );
      case PlanStatus.active:
        // Always shown on Home, so the care plan is one tap away even when
        // nothing needs doing.
        return (
          'Care Plan: Active',
          '${state.headline} · until ${state.paidUntil}'
              '${state.hasPending ? '. Renewal payment under review.' : ''}',
          Icons.check_circle_rounded,
          Accent.green,
        );
    }
  }
}
