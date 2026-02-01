import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../state/scanner_providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  late MobileScannerController _controller;
  bool _isPermissionGranted = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false, // Critical: Don't auto-start, wait for permission
      // formats: [BarcodeFormat.qrCode], // Allow all formats
    );
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final permissionService = ref.read(permissionServiceProvider);
    final status = await permissionService.getCameraPermissionStatus();

    if (mounted) {
      if (status.isGranted) {
        setState(() => _isPermissionGranted = true);
        // Small delay to ensure surface is ready
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _controller.start();
        } catch (e) {
          debugPrint('Failed to start scanner: $e');
        }
      } else {
        final hasRequested = permissionService.hasRequestedCameraPermission;
        if (!hasRequested) {
          final granted = await permissionService.requestCameraPermission();
          setState(() => _isPermissionGranted = granted);
          if (granted) {
            await Future.delayed(const Duration(milliseconds: 500));
            try {
              await _controller.start();
            } catch (e) {
              debugPrint('Failed to start scanner: $e');
            }
          }
        } else {
          setState(() => _isPermissionGranted = false);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        // MobileScanner automatically handles this usually, but explicit start/stop can be safer
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final String? code = barcodes.first.rawValue;
    if (code != null) {
      _processCode(code);
    }
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // STOP CAMERA IMMEDIATELY upon valid detection
    await _controller.stop();

    try {
      final repository = ref.read(studentRepositoryProvider);

      // 1. Try Lookup by Barcode
      var result = await repository.getStudentByBarcode(code);

      await result.fold(
        (error) async {
          // If error (or not found handled as error/null in specific cases?), log it?
          // Actually Repo returns Right(null) if not found, Left(Exception) if error.
          // However, if getStudentByBarcode fails, we will try Roll No next.
          await _tryRollNumberLookup(code);
        },
        (student) async {
          if (student != null) {
            await _navigateToPreview(student);
          } else {
            // 2. Fallback: Try Lookup by Roll Number
            await _tryRollNumberLookup(code);
          }
        },
      );
    } catch (e) {
      _handleScanError(e);
    }
  }

  Future<void> _tryRollNumberLookup(String code) async {
    final repository = ref.read(studentRepositoryProvider);
    final result = await repository.getStudentByRollNo(code);

    await result.fold(
      (error) async {
        // Show actual error to help user debug (e.g. missing index)
        _handleScanError(error);
      },
      (student) async {
        if (student != null) {
          await _navigateToPreview(student);
        } else {
          _showNotFound();
        }
      },
    );
  }

  Future<void> _navigateToPreview(student) async {
    if (!mounted) return;

    try {
      await context.push('/student-preview', extra: student);
    } catch (e) {
      print('Navigation error: $e');
    }

    // ON RETURN:
    if (mounted) {
      // Reset flag to allow scanning again
      setState(() => _isProcessing = false);
      // Restart camera
      try {
        await _controller.start();
      } catch (e) {
        print('Error restarting camera: $e');
        // Try to reinitialize if start fails
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  void _showNotFound() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Student not found (checked Barcode & Roll No)!'),
        backgroundColor: Colors.red,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
      try {
        _controller.start();
      } catch (e) {
        print('Error restarting camera: $e');
      }
    }
  }

  void _handleScanError(dynamic e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    if (mounted) {
      // Allow retry
      setState(() => _isProcessing = false);
      try {
        _controller.start();
      } catch (cameraError) {
        print('Error restarting camera: $cameraError');
      }
    }
  }

  void _showManualIdInput() {
    final TextEditingController idController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Student ID',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: idController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Student ID',
                  hintText: 'e.g., 24BFA33L12',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final id = idController.text.trim();
                  if (id.isNotEmpty) {
                    Navigator.pop(context); // Close sheet first

                    // Trigger the same lock flow
                    _processCode(id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Search Student'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Camera permission is required.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final permissionService = ref.read(permissionServiceProvider);
                  final hasRequested =
                      permissionService.hasRequestedCameraPermission;
                  if (hasRequested) {
                    await permissionService.openSettings();
                  } else {
                    await _checkPermission();
                  }
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset:
          false, // Prevent fab moving when keyboard opens (though modal handles it)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.unavailable:
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.white);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scanner Error: ${error.errorCode}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _controller.start(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
            placeholderBuilder: (context, child) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            },
            overlayBuilder: (context, constraints) {
              return Container(
                decoration: ShapeDecoration(
                  shape: QrScannerOverlayShape(
                    borderColor: AppColors.primary,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: constraints.maxWidth * 0.8,
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Align barcode within frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _showManualIdInput,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: const Text('Enter ID Manually'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Variable removed, directly using properties or constants
    // final double width = rect.width;
    // final double borderWidthSize = width / 2;
    // final double height = rect.height;
    // final double borderOffset = borderWidth / 2;

    // Using fields directly:
    // cutOutSize, cutOutBottomOffset, overlayColor, borderColor, borderWidth

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Variable boxPaint unused, removed.

    final cutOutRect = Rect.fromCenter(
      center: rect.center.translate(0, -cutOutBottomOffset),
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.saveLayer(rect, backgroundPaint);

    canvas.drawRect(rect, backgroundPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // Unused borderOffset2 removed

    // Draw corners
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + borderRadius,
          cutOutRect.top,
        )
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.top),
      borderPaint..style = PaintingStyle.stroke,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.top + borderLength)
        ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.top,
          cutOutRect.right - borderRadius,
          cutOutRect.top,
        )
        ..lineTo(cutOutRect.right - borderLength, cutOutRect.top),
      borderPaint..style = PaintingStyle.stroke,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.bottom - borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.bottom,
          cutOutRect.left + borderRadius,
          cutOutRect.bottom,
        )
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.bottom),
      borderPaint..style = PaintingStyle.stroke,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.bottom - borderLength)
        ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.bottom,
          cutOutRect.right - borderRadius,
          cutOutRect.bottom,
        )
        ..lineTo(cutOutRect.right - borderLength, cutOutRect.bottom),
      borderPaint..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
