import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Full-screen QR scanner. Push this and await the result:
///
///   final code = await Navigator.push<String>(
///     context,
///     MaterialPageRoute(builder: (context) => const QrScannerScreen()),
///   );
///   if (code != null) { ... }
///
/// Pops with the scanned string as soon as a QR code is detected. Pops
/// with null if the user backs out without scanning anything.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Guards against firing multiple times if several frames detect a code
  // before the screen has finished popping.
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _handled = true;
    Navigator.pop(context, rawValue.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Device QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // The package's own error view is only a small "!" icon, which
            // tells nobody what went wrong. Say it in words instead.
            errorBuilder: (context, error, child) =>
                _ScannerErrorView(error: error),
          ),
          // The viewfinder and the hint are for a working camera only; they
          // would sit on top of the error message otherwise.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) =>
                state.error == null ? child! : const SizedBox.shrink(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ScannerFrameOverlay(),
                Positioned(
                  bottom: 40,
                  left: 24,
                  right: 24,
                  child: Text(
                    'Point your camera at the QR code on the bottom of the '
                    'ALISTO device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
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

/// Shown instead of the camera when it cannot start: says why and what to do.
class _ScannerErrorView extends StatelessWidget {
  final MobileScannerException error;
  const _ScannerErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final title = denied
        ? 'Camera access is turned off'
        : "The camera couldn't start";
    final help = denied
        ? 'Allow the camera for ALISTO:\nPhone Settings > Apps > ALISTO > '
              'Permissions > Camera > Allow.\nThen come back and scan again.'
        : error.errorCode == MobileScannerErrorCode.unsupported
        ? 'This phone has no usable camera. Type the device serial number '
              'instead.'
        : 'Close other apps that may be using the camera, then try again. '
              'You can also type the device serial number instead.';
    // The technical reason, small, so it can be reported if it keeps happening.
    final detail = error.errorDetails?.message ?? error.errorCode.name;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded,
              color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            help,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Simple square viewfinder frame drawn over the camera preview.
class _ScannerFrameOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 3),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}