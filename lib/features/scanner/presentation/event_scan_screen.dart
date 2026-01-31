import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/student_provider.dart';

class EventScanScreen extends ConsumerStatefulWidget {
  const EventScanScreen({super.key});

  @override
  ConsumerState<EventScanScreen> createState() => _EventScanScreenState();
}

class _EventScanScreenState extends ConsumerState<EventScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false,
  );
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      case AppLifecycleState.resumed:
        if (!_isProcessing) {
          _controller.start();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final code = barcode.rawValue!;
        _handleBarcode(code);
        break;
      }
    }
  }

  Future<void> _handleBarcode(String code) async {
    setState(() => _isProcessing = true);

    // Stop camera while processing
    await _controller.stop();

    try {
      // Fetch student by barcode (or roll number if they match)
      final repository = ref.read(studentRepositoryProvider);
      final result = await repository.getStudentByBarcode(code);

      result.fold(
        (error) {
          _showError('Student not found: ${error.toString()}');
          _resumeScan();
        },
        (student) async {
          if (student != null) {
            // Navigate to verification screen with the student
            if (mounted) {
              await context.push('/verification', extra: student);
              // Resume scanning after returning
              _resumeScan();
            }
          } else {
            // Try searching by roll number just in case barcode == rollNo
            await _tryRollNoSearch(code, repository);
          }
        },
      );
    } catch (e) {
      _showError('Scanning error: $e');
      _resumeScan();
    }
  }

  Future<void> _tryRollNoSearch(String code, dynamic repository) async {
    final result = await repository.getStudentByRollNo(code);
    result.fold(
      (error) {
        _showError('Student not found.');
        _resumeScan();
      },
      (student) async {
        if (student != null) {
          if (mounted) {
            await context.push('/verification', extra: student);
            _resumeScan();
          }
        } else {
          _showError('No student found with ID/Barcode: $code');
          _resumeScan();
        }
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _resumeScan() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppColors.primary,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Align barcode/QR code within the frame',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape (simplified version of usual libraries)
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(
      Rect.fromCenter(
        center: rect.center,
        width: cutOutSize,
        height: cutOutSize,
      ),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return Path()
      ..addPath(getLeftTopPath(rect), Offset.zero)
      ..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final _cutOutSize = cutOutSize;
    final _rect = Rect.fromCenter(
      center: rect.center,
      width: _cutOutSize,
      height: _cutOutSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: _cutOutSize,
      height: _cutOutSize,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    // Top left
    path.moveTo(_rect.left, _rect.top + borderLength);
    path.lineTo(_rect.left, _rect.top);
    path.lineTo(_rect.left + borderLength, _rect.top);

    // Top right
    path.moveTo(_rect.right - borderLength, _rect.top);
    path.lineTo(_rect.right, _rect.top);
    path.lineTo(_rect.right, _rect.top + borderLength);

    // Bottom right
    path.moveTo(_rect.right, _rect.bottom - borderLength);
    path.lineTo(_rect.right, _rect.bottom);
    path.lineTo(_rect.right - borderLength, _rect.bottom);

    // Bottom left
    path.moveTo(_rect.left + borderLength, _rect.bottom);
    path.lineTo(_rect.left, _rect.bottom);
    path.lineTo(_rect.left, _rect.bottom - borderLength);

    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
