import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'device_registration_screens.dart';

// =========================================================
// STEP 1: CONNECT DEVICE TO WIFI
// =========================================================
/// Walks the user through connecting the Alisto device (Raspberry Pi) to
/// their home WiFi, since the device has no keyboard/screen of its own.
/// This now runs FIRST in the registration flow, before the serial number
/// is even asked for — the device needs to be online before anything else
/// about it makes sense to configure.
///
/// Flow:
/// 1. User connects their PHONE to the Pi's temporary hotspot ("Alisto-Setup")
///    via their phone's normal WiFi settings.
/// 2. User comes back here and enters their HOME WiFi name + password.
/// 3. This screen sends that info to the Pi (reachable at 10.42.0.1 while
///    the Pi is in hotspot mode — see CLAUDE'S FIX note below).
/// 4. On success, continues to RegisterDeviceStep1Screen to enter the
///    device's serial number. WiFi setup is required — there is no "skip"
///    option, since the device needs to be online for the rest of
///    registration (checking the serial, streaming status/location, etc.)
///    to mean anything.
class WifiSetupScreen extends StatefulWidget {
  /// True when reached from an already-registered device's own settings
  /// (see DeviceInformationScreen's "Change WiFi Network" entry) instead
  /// of first-time onboarding -- on success, this just returns to
  /// wherever the user came from instead of pushing into the device
  /// registration flow, which only makes sense the very first time.
  final bool isReconfiguring;
  const WifiSetupScreen({super.key, this.isReconfiguring = false});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  String? _statusMessage;
  bool? _lastAttemptSucceeded;

  // Default gateway IP while the Pi is broadcasting its own hotspot.
  // CLAUDE'S FIX: this was 192.168.4.1 (the typical hostapd default), but
  // `nmcli device wifi hotspot` (what the Pi's start_setup_hotspot.sh
  // actually uses) assigns 10.42.0.1 by default -- confirmed directly on
  // the real device via `ip addr show wlan0`. The mismatch meant every
  // request from the app was going to an address the phone couldn't even
  // route to on the "Alisto-Setup" network, which is why it always failed
  // with "Could not reach Alisto" no matter how many times it was retried.
  // Confirm with `ip addr show wlan0` on the Pi if this ever changes.
  static const String _piSetupUrl = 'http://10.42.0.1:5000/connect-wifi';

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _sendWifiCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      _showError('Please enter your WiFi name.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your WiFi password.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = null;
      _lastAttemptSucceeded = null;
    });

    try {
      // CLAUDE'S FIX: the Pi's own connect_to_wifi() sequence (bring the
      // hotspot down, rescan, then attempt the real connection with its
      // own 30s timeout) can legitimately take up to ~35s end to end
      // before this request even gets a response. The old 20s client
      // timeout here was SHORTER than that worst case, so the app was
      // giving up and reporting "could not reach Alisto" while the Pi
      // was still genuinely working -- which is exactly what made this
      // feel like it needed repeated retries: each "failed" attempt was
      // often actually still in progress, and retrying just restarted
      // the whole slow sequence again instead of letting it finish.
      final response = await http
          .post(
            Uri.parse(_piSetupUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ssid': ssid, 'password': password}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'] == true;
        setState(() {
          _lastAttemptSucceeded = success;
          _statusMessage = success
              ? 'Success! Alisto is connecting to "$ssid". You can now '
                    'reconnect your phone to your normal WiFi and continue.'
              : (data['message'] ??
                    'Alisto could not connect. Please check the WiFi name '
                        'and password and try again.');
        });
      } else {
        setState(() {
          _lastAttemptSucceeded = false;
          _statusMessage =
              'Alisto responded with an error (code ${response.statusCode}). Please try again.';
        });
      }
    } catch (e) {
      // CLAUDE'S FIX: the request itself can fail to complete for TWO very
      // different reasons that look identical from here: (a) Alisto
      // genuinely couldn't be reached, or (b) it actually succeeded --
      // connecting to the real WiFi makes Alisto leave the Alisto-Setup
      // hotspot mid-response, so the phone loses its only path back to it
      // before ever seeing the reply. Real device testing confirmed this
      // exact case: the Pi's own logs showed a successful connection and
      // the speaker even announced "Connected to your home WiFi", yet this
      // screen still showed this generic unreachable error every time,
      // with no way to proceed (no skip option once WiFi is required).
      //
      // Tell the two apart by polling Alisto's hotspot-mode /status
      // endpoint for a few seconds: if it stays reachable, Alisto is still
      // broadcasting the hotspot (genuine failure, safe to retry). If it
      // becomes unreachable, Alisto left hotspot mode -- which only ever
      // happens after it actually joined the real network.
      final actuallySucceeded = await _probeForSuccessAfterDrop();
      setState(() {
        _lastAttemptSucceeded = actuallySucceeded;
        _statusMessage = actuallySucceeded
            ? 'Success! Alisto connected to "$ssid" and left setup mode. '
                  'You can now reconnect your phone to your normal WiFi and continue.'
            : 'Could not reach Alisto. Make sure your phone is still connected '
                  'to the "Alisto-Setup" WiFi network, then try again.';
      });
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  /// Only called after the initial POST failed to complete (see the catch
  /// block above for why that's ambiguous). Polls Alisto's hotspot-mode
  /// status endpoint every 2s for up to 8s: if it never responds again,
  /// the hotspot is gone -- which only happens once Alisto actually left
  /// AP mode to join the real network, meaning the connect attempt that
  /// just appeared to "fail" actually succeeded.
  Future<bool> _probeForSuccessAfterDrop() async {
    const statusUrl = 'http://10.42.0.1:5000/status';
    for (var i = 0; i < 4; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        await http.get(Uri.parse(statusUrl)).timeout(const Duration(seconds: 2));
        // Still reachable -- Alisto is still in hotspot mode, so keep
        // checking (a genuine failure restores the hotspot quickly, but
        // give it the full window in case that's still in progress).
      } catch (_) {
        return true; // unreachable -- Alisto left hotspot mode -> success
      }
    }
    return false;
  }

  void _continueToSerialEntry() {
    if (widget.isReconfiguring) {
      // Already a registered device -- nothing left to set up, just
      // return to wherever this was opened from (Device Information).
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterDeviceStep1Screen(),
      ),
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
                const SizedBox(height: 8),
                Text(
                  'Connect to WiFi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(
                  currentStep: 1,
                  totalSteps: 4,
                ),
                const SizedBox(height: 24),
                _buildInstructions(context),
                const SizedBox(height: 24),
                Text(
                  'Enter your home WiFi details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'WiFi Name (SSID)',
                  hint: 'Home_WiFi_5G',
                  controller: _ssidController,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'WiFi Password',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _passwordController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Connect Alisto to WiFi',
                  loading: _isConnecting,
                  onPressed: _sendWifiCredentials,
                ),
                if (_isConnecting) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connecting Alisto to your WiFi -- this can take up '
                          'to 30 seconds. Please wait, no need to press again.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lastAttemptSucceeded == true
                          ? Colors.green.withOpacity(0.08)
                          : AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lastAttemptSucceeded == true
                            ? Colors.green
                            : AppColors.error,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _lastAttemptSucceeded == true
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _lastAttemptSucceeded == true
                              ? Colors.green
                              : AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_lastAttemptSucceeded == true) ...[
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: widget.isReconfiguring ? 'Done' : 'Continue',
                    onPressed: _continueToSerialEntry,
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Connect your phone to Alisto',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '1. Open your phone\'s WiFi settings.\n'
          '2. Look for a network named "Alisto-Setup" and connect to it.\n'
          '3. Come back to this screen once connected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}