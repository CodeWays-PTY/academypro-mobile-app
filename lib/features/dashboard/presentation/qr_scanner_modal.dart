import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/checkin_controller.dart';

class QrScannerModal extends ConsumerStatefulWidget {
  const QrScannerModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => const QrScannerModal(),
    );
  }

  @override
  ConsumerState<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends ConsumerState<QrScannerModal> {
  MobileScannerController? _controller;
  bool _isProcessingScan = false;
  String? _bannerMessage;
  bool _bannerIsSuccess = true;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_isProcessingScan) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        setState(() {
          _isProcessingScan = true;
        });

        final result = ref.read(checkInProvider.notifier).processQRScan(rawValue);

        _bannerTimer?.cancel();
        setState(() {
          _bannerMessage = result.message;
          _bannerIsSuccess = result.success && !result.isDuplicate;
        });

        _bannerTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _bannerMessage = null;
              _isProcessingScan = false;
            });
          }
        });
      }
    }
  }

  Widget _buildCameraErrorWidget(BuildContext context, MobileScannerException error) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Color(0xFFEF4444), size: 54.0),
          const SizedBox(height: 16.0),
          const Text(
            'Camera Access Required',
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Please enable camera permissions in app settings to scan player QR codes.\nDetails: ${error.errorCode.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A), size: 24.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE QR SCANNER',
              style: TextStyle(
                color: Color(0xFF003EC7),
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Checked In: ${checkInState.checkedInCount} / ${checkInState.totalCount} Athletes',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Color(0xFF2563EB)),
            onPressed: () => _controller?.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Color(0xFF2563EB)),
            onPressed: () => _controller?.switchCamera(),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Toast Banner for Live Non-Blocking Feedback
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _bannerMessage != null
                  ? Container(
                      key: ValueKey(_bannerMessage),
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _bannerIsSuccess ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: (_bannerIsSuccess ? Colors.green : Colors.amber).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _bannerIsSuccess ? Icons.check_circle : Icons.info_outline,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              _bannerMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(height: 8.0),
            ),

            // Live Camera Viewfinder
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Live MobileScanner Stream Widget
                      if (_controller != null)
                        MobileScanner(
                          controller: _controller!,
                          onDetect: _handleDetect,
                          errorBuilder: (context, error) {
                            return _buildCameraErrorWidget(context, error);
                          },
                        ),

                      // Target Reticle Box Frame Overlay
                      Container(
                        width: 250.0,
                        height: 250.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: _bannerMessage != null && _bannerIsSuccess
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF2563EB),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_bannerIsSuccess ? const Color(0xFF22C55E) : const Color(0xFF2563EB))
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // Instruction Banner
                      Positioned(
                        bottom: 20.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.center_focus_strong, color: Color(0xFF38BDF8), size: 16.0),
                              SizedBox(width: 6.0),
                              Text(
                                'Align athlete QR code inside box',
                                style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Light Theme Action Bottom Bar (No Pending Team Buttons Tray)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003EC7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        child: const Text(
                          'Done Scanning',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
