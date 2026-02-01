import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/providers/student_provider.dart';
import '../../../domain/entities/student.dart';
import '../../verification/presentation/verification_choice_screen.dart';

class ImprovedEventScanScreen extends ConsumerStatefulWidget {
  const ImprovedEventScanScreen({super.key});

  @override
  ConsumerState<ImprovedEventScanScreen> createState() =>
      _ImprovedEventScanScreenState();
}

class _ImprovedEventScanScreenState
    extends ConsumerState<ImprovedEventScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.all], // Explicitly look for all or specific formats
    torchEnabled: false,
    returnImage: false, // Don't return image image bytes to save processing
  );

  bool _isProcessing = false;
  Student? _scannedStudent;
  String? _errorMessage;
  int _scanCount = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final TextEditingController _rollNoController = TextEditingController(
    text: '25BFA33',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _animationController.dispose();
    _rollNoController.dispose();
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
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _scannedStudent = null;
    });

    // Stop camera while processing
    await _controller.stop();

    // Play success animation
    _animationController.forward().then((_) => _animationController.reverse());

    try {
      // Fetch student by barcode
      final repository = ref.read(studentRepositoryProvider);
      final result = await repository.getStudentByBarcode(code);

      await result.fold(
        (error) async {
          // Try roll number as fallback
          await _tryRollNoSearch(code, repository);
        },
        (student) async {
          if (student != null) {
            setState(() {
              _scannedStudent = student;
              _scanCount++;
            });

            // Show preview for 1.5 seconds then navigate
            await Future.delayed(const Duration(milliseconds: 1500));

            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerificationChoiceScreen(student: student),
                ),
              );
              _resumeScan();
            }
          } else {
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
        _showError('Student not found');
        _resumeScan();
      },
      (student) async {
        if (student != null) {
          setState(() {
            _scannedStudent = student;
            _scanCount++;
          });

          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerificationChoiceScreen(student: student),
              ),
            );
            _resumeScan();
          }
        } else {
          _showError('No student found with ID: $code');
          _resumeScan();
        }
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
    });

    // Auto-clear error and resume after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _errorMessage = null);
        _resumeScan();
      }
    });
  }

  void _resumeScan() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _scannedStudent = null;
      _errorMessage = null;
    });
    _controller.start();
  }

  Future<void> _searchByRollNo() async {
    final rollNo = _rollNoController.text.trim();
    if (rollNo.isEmpty) {
      _showError('Please enter a roll number');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _scannedStudent = null;
    });

    await _controller.stop();

    try {
      final repository = ref.read(studentRepositoryProvider);
      final result = await repository.getStudentByRollNo(rollNo);

      result.fold(
        (error) {
          _showError('Student not found: $rollNo');
        },
        (student) async {
          if (student != null) {
            setState(() {
              _scannedStudent = student;
              _scanCount++;
            });

            await Future.delayed(const Duration(milliseconds: 1500));

            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerificationChoiceScreen(student: student),
                ),
              );
              _resumeScan();
            }
          } else {
            _showError('No student found with roll number: $rollNo');
          }
        },
      );
    } catch (e) {
      _showError('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Event Check-In'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Scan counter
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_scanCount scanned',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Torch toggle
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: state.torchState == TorchState.on
                      ? Colors.yellow
                      : Colors.white,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),

          // Scan Frame Overlay
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 280,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isProcessing
                        ? Colors.green
                        : (_errorMessage != null
                              ? Colors.red
                              : Colors.white.withOpacity(0.8)),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: _CornersPainter(
                    color: _isProcessing
                        ? Colors.green
                        : (_errorMessage != null ? Colors.red : Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // Student Info Preview (Success State)
          if (_scannedStudent != null && _errorMessage == null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _scannedStudent!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scannedStudent!.rollNo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Opening verification...',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Error Message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resuming scan...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Processing Overlay
          if (_isProcessing && _scannedStudent == null && _errorMessage == null)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Looking up student...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Instructions and Manual Entry
          if (!_isProcessing &&
              _errorMessage == null &&
              _scannedStudent == null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Scan instruction
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Scan Student ID Barcode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider with "OR"
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Manual entry
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Enter Roll Number',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rollNoController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: '25BFA33L12',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                                onSubmitted: (_) => _searchByRollNo(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _searchByRollNo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.search, size: 24),
                            ),
                          ],
                        ),
                      ],
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

// Custom painter for corner indicators
class _CornersPainter extends CustomPainter {
  final Color color;

  _CornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;
    const offset = 0.0;

    // Top-left
    canvas.drawLine(
      Offset(offset, offset + cornerLength),
      Offset(offset, offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, offset),
      Offset(offset + cornerLength, offset),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - offset - cornerLength, offset),
      Offset(size.width - offset, offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, offset),
      Offset(size.width - offset, offset + cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(offset, size.height - offset - cornerLength),
      Offset(offset, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, size.height - offset),
      Offset(offset + cornerLength, size.height - offset),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - offset - cornerLength, size.height - offset),
      Offset(size.width - offset, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, size.height - offset - cornerLength),
      Offset(size.width - offset, size.height - offset),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
