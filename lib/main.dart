import 'package:flutter/material.dart';

void main() {
  runApp(const AlistoApp());
}

// =========================================================
// THEME — single source of truth for colors, type, buttons
// =========================================================
class AppColors {
  static const primary = Color(0xFF2F80ED);
  static const primaryDark = Color(0xFF1B5FC9);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F9FC);
  static const textPrimary = Color(0xFF1A1D1F);
  static const textSecondary = Color(0xFF6F767E);
  static const border = Color(0xFFE0E4E8);
  static const error = Color(0xFFE84C4C);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        background: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border, width: 1.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}

// =========================================================
// RESPONSIVE HELPERS
// =========================================================
extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.of(this).size;
  double get sw => screen.width;
  double get sh => screen.height;

  /// Clamp a value so tiny phones and huge tablets both stay usable.
  double clampHeight(double fraction, {double min = 0, double max = double.infinity}) {
    return (sh * fraction).clamp(min, max);
  }
}

/// Keeps content from stretching edge-to-edge on tablets/web while staying
/// fluid on phones of any size.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveContent({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// =========================================================
// APP ROOT
// =========================================================
class AlistoApp extends StatelessWidget {
  const AlistoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alisto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

// =========================================================
// SPLASH SCREEN
// =========================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = context.clampHeight(0.14, min: 80, max: 140);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/alisto_logo.png',
              width: logoSize,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.favorite_rounded,
                size: logoSize,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Alisto', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Help, Always Within Reach.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// WELCOME SCREEN — flex-based layout, no more dead space
// =========================================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Welcome to Alisto',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "Let's connect your device and keep you safe.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                // Illustration takes the majority of the free space,
                // so it grows/shrinks with the screen instead of
                // leaving a blank gap.
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Image.asset(
                      'assets/images/welcome_illustration.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.people_alt_rounded,
                        size: context.clampHeight(0.18, min: 100, max: 200),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Expanded(flex: 1, child: Container()),
                PrimaryButton(
                  label: 'Get Started',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'I already have an account',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// LOGIN SCREEN
// =========================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          // Scrollable + keyboard-safe: prevents overflow when the
          // keyboard opens on small devices.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/login_illustration.png',
                    height: context.clampHeight(0.12, min: 70, max: 110),
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.account_circle_rounded,
                      size: context.clampHeight(0.1, min: 64, max: 90),
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Login Account', style: Theme.of(context).textTheme.headlineSmall),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Sign in to keep watching over what matters',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Phone Number',
                  hint: '0917 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Log in',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichSwitchLink(
                    prompt: "Don't have an account? ",
                    action: 'Sign up',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// ROLE SELECTION SCREEN
// =========================================================
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Choose Your Role', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text('Who is this account for?', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                _RoleCard(
                  icon: Icons.home_rounded,
                  title: 'I have an Alisto device',
                  subtitle: 'I will set up and manage the device.',
                  selected: _selected == 0,
                  onTap: () => setState(() => _selected = 0),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: 'I was added as contact',
                  subtitle: 'I will receive alerts and stay informed.',
                  selected: _selected == 1,
                  onTap: () => setState(() => _selected = 1),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterDeviceStep1Screen()),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.07) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 52, color: selected ? AppColors.primary : AppColors.primary.withOpacity(0.4)),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// SIGN UP SCREEN
// =========================================================
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/signup_avatar.png',
                    height: context.clampHeight(0.1, min: 64, max: 90),
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_add_alt_1_rounded,
                      size: context.clampHeight(0.09, min: 56, max: 80),
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text('Create Account', style: Theme.of(context).textTheme.headlineSmall),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Sign up to get started with Alisto',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(label: 'Name', hint: 'Maria Santos'),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone Number',
                  hint: '0917 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreeTerms,
                        onChanged: (value) => setState(() => _agreeTerms = value ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I agree to the Terms and Conditions and Privacy Policy',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Sign Up',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichSwitchLink(
                    prompt: 'Already have an account? ',
                    action: 'Login',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// REGISTER DEVICE FLOW — STEP 1: SCAN / ENTER SERIAL
// =========================================================
class RegisterDeviceStep1Screen extends StatelessWidget {
  const RegisterDeviceStep1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Register Device', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(currentStep: 1, totalSteps: 3),
                const SizedBox(height: 24),
                const Center(child: DeviceStickerPreview(serial: '2026-0718ALISTO09X3')),
                const SizedBox(height: 20),
                Text(
                  'Enter the unique serial number found at the bottom of your ALISTO device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    hintText: '2026-0718ALISTO09X3',
                    suffixIcon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative mock-up of the physical serial sticker on the device —
/// drawn entirely with widgets, no image asset needed.
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
          // Corner alignment marks, like a real sticker/QR frame.
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Help, Always Within Reach.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
              ),
              const SizedBox(height: 10),
              const Icon(Icons.qr_code_2_rounded, size: 56, color: AppColors.textPrimary),
              const SizedBox(height: 8),
              Text(serial, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9)),
              Text(
                'Scan to view device',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// REGISTER DEVICE FLOW — STEP 2: PERSONAL INFORMATION
// =========================================================
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  String _selectedSex = 'Female';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Personal Information', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(currentStep: 2, totalSteps: 3),
                const SizedBox(height: 20),
                Center(
                  child: ProfileAvatarPicker(
                    onTap: () {
                      // TODO: open image picker / camera
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const AppTextField(label: 'Name', hint: 'Maria Santos'),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: AppTextField(
                        label: 'Age',
                        hint: '65',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SexDropdownField(
                        value: _selectedSex,
                        onChanged: (value) => setState(() => _selectedSex = value ?? _selectedSex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const AppTextField(
                  label: 'Contact Number',
                  hint: '0917 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetHomeAddressScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain avatar icon with a small "+" badge — signals "tap to add a
/// photo" without needing an actual image asset.
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
              child: Icon(Icons.person_rounded, size: size * 0.55, color: AppColors.textSecondary),
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
                child: Icon(Icons.add_rounded, size: badgeSize * 0.6, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SexDropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _SexDropdownField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sex', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Male', child: Text('Male')),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

// =========================================================
// REGISTER DEVICE FLOW — STEP 3: SET HOME ADDRESS
// =========================================================
class SetHomeAddressScreen extends StatelessWidget {
  const SetHomeAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Set Home Address', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(currentStep: 3, totalSteps: 3),
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/images/House.png',
                    height: context.clampHeight(0.16, min: 120, max: 170),
                    errorBuilder: (context, error, stackTrace) =>
                        const IllustrationPlaceholder(icon: Icons.cottage_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: AppTextField(label: 'House / Unit No.', hint: '123')),
                    SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        label: 'Zip Code',
                        hint: '6000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const AppTextField(label: 'Street / Purok', hint: 'Purok 4, Labangon'),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: AppTextField(label: 'Barangay', hint: 'Labangon')),
                    SizedBox(width: 14),
                    Expanded(child: AppTextField(label: 'City', hint: 'Cebu City')),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Submit',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationCompleteScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// REGISTER DEVICE FLOW — SUCCESS
// =========================================================
class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: context.clampHeight(0.05, min: 20, max: 48)),
                Image.asset(
                  'assets/images/registrationcomplete.png',
                  height: context.clampHeight(0.22, min: 150, max: 210),
                  errorBuilder: (context, error, stackTrace) => const SuccessIllustration(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Registration Complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Alisto device has been successfully registered.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: context.clampHeight(0.06, min: 32, max: 64)),
                PrimaryButton(
                  label: 'Add Contacts',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavScreen(initialIndex: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Go to Dashboard',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavScreen()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Family + shield illustration built from icons — used as the
/// errorBuilder fallback for registrationcomplete.png so the screen
/// still looks intentional if the asset is ever missing.
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
          const Icon(Icons.diversity_1_rounded, size: 88, color: AppColors.primary),
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
              child: const Icon(Icons.verified_rounded, size: 22, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// REUSABLE WIDGETS (onboarding flow)
// =========================================================

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const SecondaryButton({super.key, required this.label, required this.onPressed});

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
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Soft circular icon placeholder — errorBuilder fallback for
/// House.png so Step 3 still looks intentional if the asset is
/// ever missing.
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withOpacity(0.08)),
      child: Icon(icon, size: size * 0.5, color: tint),
    );
  }
}

/// A transparent AppBar with just a back arrow, aligned to the same
/// horizontal guide (24px) as the page content below it.
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

/// Shared step-progress indicator (dots + connecting lines) for the
/// multi-step Register Device flow.
class RegisterDeviceStepIndicator extends StatelessWidget {
  final int currentStep; // 1-based
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
        Text('Step $currentStep of $totalSteps', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Row(
          children: List.generate(totalSteps * 2 - 1, (index) {
            // Even indices are dots, odd indices are connecting lines.
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
// DASHBOARD — extra accent colors used by Home/History/Contacts
// (kept separate from AppColors since those are onboarding-specific)
// =========================================================
class _Accent {
  static const green = Color(0xFF2FAE68);
  static const purple = Color(0xFF9B6BEA);
  static const pink = Color(0xFFEB5B84);
  static const yellow = Color(0xFFE0A93B);
  static const blue = AppColors.primary;
}

// =========================================================
// MAIN NAV SHELL — bottom tab bar + IndexedStack
// =========================================================
class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _index = widget.initialIndex;

  static const _pages = [
    HomeScreen(),
    HistoryScreen(),
    ContactsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _AppBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AppBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.history_rounded, label: 'History'),
    (icon: Icons.contacts_rounded, label: 'Contacts'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final item = _items[i];
            final color = selected ? AppColors.primary : AppColors.textSecondary;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: color),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// =========================================================
// DASHBOARD SHARED SMALL PIECES
// =========================================================

/// White/surface rounded card used as the base container everywhere.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  const _Card({
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

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
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const _InitialsAvatar({required this.initials, required this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.16), shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.32, color: color),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16.5)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// =========================================================
// HOME SCREEN
// =========================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 18),
              const _DeviceStatusCard(),
              const SizedBox(height: 16),
              const _MedicineReminderCard(),
              const SizedBox(height: 18),
              const _SectionLabel('Quick Actions'),
              const SizedBox(height: 10),
              const _QuickActionsRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, Maria!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
              Text('Stay safe today.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 26),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: const Text('2',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Device Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
              const _StatusPill(label: 'Online', color: _Accent.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _StatTile(
                  icon: Icons.battery_charging_full_rounded,
                  color: _Accent.green,
                  label: 'Battery Level',
                  value: '48%',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.sim_card_rounded,
                  color: _Accent.blue,
                  label: 'Sim Number',
                  value: '09171234567',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: _StatTile(
                  icon: Icons.location_on_rounded,
                  color: _Accent.purple,
                  label: 'GPS',
                  value: 'Active',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.error,
                  label: 'Last Alert',
                  value: '09:30 PM',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineReminderCard extends StatelessWidget {
  const _MedicineReminderCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Medicine Reminder',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
              const Text('View All',
                  style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          const _MedicineRow(name: 'Medicine 1', time: '09:00 - 10:00 AM', status: 'Notified', notified: true),
          const SizedBox(height: 8),
          const _MedicineRow(name: 'Medicine 2', time: '09:00 - 10:00 PM', status: 'Upcoming', notified: false),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.notifications_none_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text("Stay on track. Don't forget your medicine",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final String name;
  final String time;
  final String status;
  final bool notified;
  const _MedicineRow({required this.name, required this.time, required this.status, required this.notified});

  @override
  Widget build(BuildContext context) {
    final color = notified ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(time, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          _StatusPill(label: status, color: color),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.medication_rounded,
            title: 'Add Medicine',
            subtitle: 'Set medicine details and reminder schedules',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.gps_fixed_rounded,
            title: 'Find Alisto',
            subtitle: 'View the current location of the Alisto device',
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _QuickActionCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HISTORY SCREEN
// =========================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _tab = 0;
  static const _tabs = ['All', 'Emergency', 'System'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('History', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22)),
              ),
              const SizedBox(height: 14),
              _SegmentedTabs(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 14),
              const _DateFilterRow(),
              const SizedBox(height: 16),
              Text('Today · May 18, 2026',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const _HistoryEntryCard(
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.error,
                title: 'Manual Alert Triggered',
                titleColor: AppColors.error,
                time: '09:30 PM',
                lines: ['Emergency Button Pressed', 'Barangay Sudlon 2, Cebu City'],
                highlighted: true,
              ),
              const SizedBox(height: 10),
              const _HistoryEntryCard(
                icon: Icons.medication_rounded,
                iconColor: AppColors.primary,
                title: 'Medicine Reminder',
                time: '09:00 AM',
                lines: ['Medicine 1 - Notified'],
              ),
              const SizedBox(height: 10),
              const _HistoryEntryCard(
                icon: Icons.battery_alert_rounded,
                iconColor: _Accent.green,
                title: 'Low Battery',
                time: '07:45 AM',
                lines: ['Battery level is below 20%'],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _SegmentedTabs({required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final selected = i == index;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('May 12, 2026 - May 18, 2026',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(Icons.file_download_outlined, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Export', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String time;
  final List<String> lines;
  final bool highlighted;

  const _HistoryEntryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.time,
    required this.lines,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: highlighted ? AppColors.error.withOpacity(0.05) : AppColors.surface,
      borderColor: highlighted ? AppColors.error.withOpacity(0.35) : AppColors.border,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5, color: titleColor ?? AppColors.textPrimary)),
                    ),
                    Text(time,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 3),
                for (final line in lines)
                  Text(line, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// CONTACTS SCREEN
// =========================================================
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('Contacts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22)),
              ),
              const SizedBox(height: 14),
              const _EmergencyContactsBanner(),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_rounded, size: 18, color: _Accent.pink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Family Contacts',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                        Text('People who will receive alerts first.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Add Contact',
                                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Card(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    const _ContactTile(
                      initials: 'JS',
                      color: _Accent.purple,
                      name: 'Juan Santos',
                      relation: 'Son',
                      phone: '0917 123 4567',
                    ),
                    const _Divider(),
                    const _ContactTile(
                      initials: 'AS',
                      color: _Accent.pink,
                      name: 'Anna Marie Santos',
                      relation: 'Daughter',
                      phone: '0908 765 4321',
                    ),
                    const _Divider(),
                    const _ContactTile(
                      initials: 'MS',
                      color: _Accent.yellow,
                      name: 'Maria Santos',
                      relation: 'Sister',
                      phone: '0935 111 2233',
                    ),
                    const _Divider(),
                    _EditLinkRow(label: 'Edit Family Contacts', onTap: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 18, color: _Accent.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Barangay Health Worker',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                        Text('Health worker who can call assist during emergencies.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Card(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    const _ContactTile(
                      initials: 'AL',
                      color: _Accent.green,
                      name: 'Alma Lopez - Sudlon 2',
                      relation: 'BHW',
                      phone: '0916 456 7890',
                    ),
                    const _Divider(),
                    _EditLinkRow(label: 'Edit Barangay Health Worker Contacts', onTap: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Make sure your contacts are updated so they can receive alerts when needed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactsBanner extends StatelessWidget {
  const _EmergencyContactsBanner();

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: AppColors.primary.withOpacity(0.06),
      borderColor: AppColors.primary.withOpacity(0.25),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.14), shape: BoxShape.circle),
            child: const Icon(Icons.groups_rounded, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Emergency Contacts',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('These people will receive emergency alerts from your Alisto device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('4', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                Text('Total', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String initials;
  final Color color;
  final String name;
  final String relation;
  final String phone;
  const _ContactTile({
    required this.initials,
    required this.color,
    required this.name,
    required this.relation,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _InitialsAvatar(initials: initials, color: color, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('$relation · $phone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.call_rounded, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _EditLinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EditLinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(label,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}

// =========================================================
// PROFILE SCREEN
// =========================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 34),
                  Text('Profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.settings_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ProfileHeaderCard(),
              const SizedBox(height: 18),
              const _ProfileNavTile(
                icon: Icons.person_rounded,
                color: _Accent.purple,
                title: 'Personal Information',
                subtitle: 'View and manage your personal details',
              ),
              const SizedBox(height: 10),
              const _ProfileNavTile(
                icon: Icons.smartphone_rounded,
                color: _Accent.blue,
                title: 'Device Information',
                subtitle: 'View details about your Alisto device',
              ),
              const SizedBox(height: 10),
              const _ProfileNavTile(
                icon: Icons.support_agent_rounded,
                color: _Accent.yellow,
                title: 'Help & Support',
                subtitle: 'FAQs, guides and customer support',
              ),
              const SizedBox(height: 10),
              const _ProfileNavTile(
                icon: Icons.smartphone_rounded,
                color: AppColors.textSecondary,
                title: 'About Alisto',
                subtitle: 'App information and terms',
              ),
              const SizedBox(height: 22),
              _LogOutButton(onTap: () {}),
              const SizedBox(height: 10),
              Center(
                child: Text('App Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: AppColors.primary.withOpacity(0.07),
      borderColor: AppColors.primary.withOpacity(0.18),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: const Icon(Icons.person_rounded, size: 44, color: AppColors.textSecondary),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Maria Santos',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Device User',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
                const SizedBox(height: 8),
                const _ProfileMetaRow(icon: Icons.cake_rounded, text: 'May 12, 1950 (74 years old)'),
                const SizedBox(height: 4),
                const _ProfileMetaRow(icon: Icons.location_on_rounded, text: 'Sudlon 2, Cebu City'),
                const SizedBox(height: 4),
                const _ProfileMetaRow(icon: Icons.call_rounded, text: '0917 123 4567'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfileMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _ProfileNavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ProfileNavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap ?? () {},
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error.withOpacity(0.12),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 17, color: AppColors.error),
              SizedBox(width: 8),
              Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// SETTINGS SCREEN
// =========================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emergencyAlerts = true;
  bool _medicineReminders = true;
  bool _deviceAlerts = true;
  bool _locationUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text('Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
      ),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SettingsGroupLabel('Notifications'),
              const SizedBox(height: 8),
              _ToggleTile(
                icon: Icons.notifications_active_rounded,
                color: AppColors.error,
                title: 'Emergency Alerts',
                subtitle: 'Get notified for emergency events',
                value: _emergencyAlerts,
                onChanged: (v) => setState(() => _emergencyAlerts = v),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                icon: Icons.medication_rounded,
                color: _Accent.blue,
                title: 'Medicine Reminders',
                subtitle: 'Receive reminders for medicines',
                value: _medicineReminders,
                onChanged: (v) => setState(() => _medicineReminders = v),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                icon: Icons.phone_android_rounded,
                color: _Accent.yellow,
                title: 'Device Alerts',
                subtitle: 'Notifications about device status',
                value: _deviceAlerts,
                onChanged: (v) => setState(() => _deviceAlerts = v),
              ),
              const SizedBox(height: 18),
              const _SettingsGroupLabel('App & Data'),
              const SizedBox(height: 8),
              _ToggleTile(
                icon: Icons.location_on_rounded,
                color: _Accent.purple,
                title: 'Location Updates',
                subtitle: 'Allow location access for tracking',
                value: _locationUpdates,
                onChanged: (v) => setState(() => _locationUpdates = v),
              ),
              const SizedBox(height: 18),
              const _SettingsGroupLabel('Security'),
              const SizedBox(height: 8),
              _ProfileNavTile(
                icon: Icons.lock_rounded,
                color: _Accent.blue,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  final String text;
  const _SettingsGroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}