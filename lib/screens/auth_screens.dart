import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'device_registration_screens.dart';
import 'legal_screens.dart';
import 'main_nav_screen.dart';

/// Loose email check — good enough to catch typos before hitting Firebase,
/// which does the authoritative validation.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

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
// WELCOME SCREEN
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
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'I already have an account',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
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
// LOGIN SCREEN — email + password
// =========================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _loading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _loading = true);
    final error = await AuthService.login(
      email: email,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showError(error);
      return;
    }
    // AuthGate (in main.dart) will now pick up the login automatically
    // and route to the right screen — but we also navigate directly so
    // the user doesn't have to wait on this screen.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthRoutingGate()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

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
                  child: Text(
                    'Login Account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Log in',
                  loading: _loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichSwitchLink(
                    prompt: "Don't have an account? ",
                    action: 'Sign up',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
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
// SIGN UP SCREEN — full name, email, phone, password, confirm
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
  bool _loading = false;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = () => _openLegal(0);
    _privacyRecognizer = TapGestureRecognizer()..onTap = () => _openLegal(1);
  }

  void _openLegal(int tab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TermsPrivacyScreen(initialTab: tab),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// Returns an error message, or null when everything checks out.
  String? _validate() {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (!fullName.contains(' ')) {
      return 'Please enter your full name (first and last name).';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (phoneDigits.length < 10) {
      return 'Please enter a valid phone number.';
    }
    if (_passwordController.text.length < 6) {
      return 'Password should be at least 6 characters.';
    }
    if (_passwordController.text != _confirmController.text) {
      return 'Passwords do not match.';
    }
    if (!_agreeTerms) {
      return 'Please agree to the Terms and Conditions.';
    }
    return null;
  }

  Future<void> _handleSignup() async {
    final validationError = _validate();
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _loading = true);
    final error = await AuthService.signUp(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showError(error);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DeviceChoiceScreen()),
    );
  }

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
                  child: Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Sign up to get started with Alisto',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Full Name',
                  keyboardType: TextInputType.name,
                  controller: _fullNameController,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  controller: _phoneController,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: _obscureConfirm,
                  controller: _confirmController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
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
                        onChanged: (value) =>
                            setState(() => _agreeTerms = value ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              recognizer: _termsRecognizer,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              recognizer: _privacyRecognizer,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Sign Up',
                  loading: _loading,
                  onPressed: _handleSignup,
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichSwitchLink(
                    prompt: 'Already have an account? ',
                    action: 'Login',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
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
// DEVICE CHOICE SCREEN
// This app only ever creates "family" accounts (role is fixed at
// signup) — the only choice left is whether this account is setting up
// a brand-new device or joining one someone else already registered.
// =========================================================
class DeviceChoiceScreen extends StatefulWidget {
  const DeviceChoiceScreen({super.key});

  @override
  State<DeviceChoiceScreen> createState() => _DeviceChoiceScreenState();
}

class _DeviceChoiceScreenState extends State<DeviceChoiceScreen> {
  int _selected = 0;

  void _handleContinue() {
    if (_selected == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RegisterDeviceStep1Screen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LinkDeviceScreen()),
      );
    }
  }

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
                Text(
                  'Set Up Your Device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Are you registering a new Alisto device, or joining one '
                  'a family member already set up?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                _RoleCard(
                  icon: Icons.home_rounded,
                  title: 'Register a new device',
                  subtitle: 'I have an Alisto device to set up.',
                  selected: _selected == 0,
                  onTap: () => setState(() => _selected = 0),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: 'Join an existing device',
                  subtitle: 'A family member already registered it.',
                  selected: _selected == 1,
                  onTap: () => setState(() => _selected = 1),
                ),
                const Spacer(),
                PrimaryButton(label: 'Continue', onPressed: _handleContinue),
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
            color: selected
                ? AppColors.primary.withOpacity(0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 52,
                color: selected
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.4),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 17),
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
// ROUTING GATE — decides where a just-logged-in user should land
// =========================================================
/// Used right after login to route the user to the correct place
/// (device choice / registration / dashboard) based on what's already
/// saved in Firestore. main.dart's AuthGate delegates straight to this
/// widget once a Firebase Auth session exists, so this is the single
/// source of truth for both post-login and app-startup routing.
class AuthRoutingGate extends StatelessWidget {
  const AuthRoutingGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: FirestoreService.userProfileStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Every account is a "family" account now — the only remaining
        // question is whether it's linked to an elder/device yet.
        return FutureBuilder<bool>(
          future: FirestoreService.hasDevice(),
          builder: (context, deviceSnapshot) {
            if (!deviceSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return deviceSnapshot.data!
                ? const MainNavScreen()
                : const DeviceChoiceScreen();
          },
        );
      },
    );
  }
}