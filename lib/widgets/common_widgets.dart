import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// =========================================================
// BUTTONS & INPUTS
// =========================================================
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final TextEditingController? controller;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

// =========================================================
// APP BAR / NAV PIECES
// =========================================================
class MinimalBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MinimalBackAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

class RegisterDeviceStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RegisterDeviceStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $currentStep of $totalSteps',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(totalSteps * 2 - 1, (index) {
            if (index.isOdd) {
              final segmentStep = (index / 2).ceil();
              final filled = segmentStep < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: filled ? AppColors.primary : AppColors.border,
                ),
              );
            }
            final step = index ~/ 2 + 1;
            final reached = step <= currentStep;
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: reached ? AppColors.primary : AppColors.border,
                  width: 1.6,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class RichSwitchLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const RichSwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.bodySmall),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// ILLUSTRATIONS / DECORATIVE
// =========================================================
class IllustrationPlaceholder extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const IllustrationPlaceholder({
    super.key,
    required this.icon,
    this.size = 140,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withOpacity(0.08),
      ),
      child: Icon(icon, size: size * 0.5, color: tint),
    );
  }
}

class ProfileAvatarPicker extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const ProfileAvatarPicker({super.key, this.onTap, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.34;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + badgeSize / 2,
        height: size + badgeSize / 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.4),
              ),
              child: Icon(
                Icons.person_rounded,
                size: size * 0.55,
                color: AppColors.textSecondary,
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2.2),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: badgeSize * 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceStickerPreview extends StatelessWidget {
  final String serial;
  const DeviceStickerPreview({super.key, required this.serial});

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1.4),
            ),
          ),
          for (final alignment in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Alisto',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                'Help, Always Within Reach.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 9),
              ),
              const SizedBox(height: 10),
              const Icon(
                Icons.qr_code_2_rounded,
                size: 56,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 8),
              Text(
                serial.isEmpty ? '—' : serial,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 9),
              ),
              Text(
                'Scan to view device',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SuccessIllustration extends StatelessWidget {
  const SuccessIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.08),
            ),
          ),
          const Icon(
            Icons.diversity_1_rounded,
            size: 88,
            color: AppColors.primary,
          ),
          Positioned(
            top: 8,
            right: 18,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 3),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// DASHBOARD SHARED PIECES
// =========================================================
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
          color: color,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontSize: 16.5),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}
