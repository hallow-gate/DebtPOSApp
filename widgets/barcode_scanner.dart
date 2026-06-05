import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/constants.dart';

class BarcodeScannerModal extends StatefulWidget {
  final Function(String) onDetected;
  final VoidCallback onClose;
  final String title;

  const BarcodeScannerModal({
    super.key,
    required this.onDetected,
    required this.onClose,
    this.title = 'Scan Barcode',
  });

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  String? lastScan;
  bool _isScanning = true;
  late AnimationController _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _scanAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width > 480 ? 480 : double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: cameraController,
                      onDetect: (capture) {
                        if (!_isScanning) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null && _isScanning) {
                            _isScanning = false;
                            setState(() => lastScan = barcode.rawValue);
                            widget.onDetected(barcode.rawValue!);
                            widget.onClose();
                            return;
                          }
                        }
                      },
                    ),
                    if (_isScanning)
                      AnimatedBuilder(
                        animation: _scanAnimation,
                        builder: (context, child) {
                          return Positioned(
                            left: 0,
                            right: 0,
                            top: _scanAnimation.value * 260,
                            child: Container(
                              height: 2,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Corner markers
                    Positioned(
                      top: 24, left: 24,
                      child: Container(width: 24, height: 24, decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.primary, width: 3), left: BorderSide(color: AppColors.primary, width: 3)),
                      )),
                    ),
                    Positioned(
                      top: 24, right: 24,
                      child: Container(width: 24, height: 24, decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.primary, width: 3), right: BorderSide(color: AppColors.primary, width: 3)),
                      )),
                    ),
                    Positioned(
                      bottom: 24, left: 24,
                      child: Container(width: 24, height: 24, decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.primary, width: 3), left: BorderSide(color: AppColors.primary, width: 3)),
                      )),
                    ),
                    Positioned(
                      bottom: 24, right: 24,
                      child: Container(width: 24, height: 24, decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.primary, width: 3), right: BorderSide(color: AppColors.primary, width: 3)),
                      )),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Point the camera at a barcode or QR code',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (lastScan != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Text(
                  'Detected: $lastScan',
                  style: const TextStyle(color: AppColors.success, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}