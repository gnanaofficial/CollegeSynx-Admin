import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/verification_service.dart';
import '../../../data/providers/verification_provider.dart';
import '../../../domain/entities/student.dart';
import 'multi_angle_face_registration_screen.dart';

class StudentVerificationScreen extends ConsumerStatefulWidget {
  final Student student;

  const StudentVerificationScreen({super.key, required this.student});

  @override
  ConsumerState<StudentVerificationScreen> createState() =>
      _StudentVerificationScreenState();
}

class _StudentVerificationScreenState
    extends ConsumerState<StudentVerificationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isVerifying = false;
  String? _statusMessage;
  VerificationResult? _result;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera found');
        return;
      }

      // Use FRONT camera for student self-verification
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Camera error: $e');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Verifying...';
      _result = null;
    });

    try {
      final image = await _cameraController!.takePicture();

      final service = ref.read(verificationServiceProvider);

      final result = await service.verifyStudent(
        student: widget.student,
        livePhoto: image,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _statusMessage = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _syncEmbeddings() async {
    setState(() => _statusMessage = 'Syncing class data...');
    try {
      final service = ref.read(verificationServiceProvider);
      await service.syncClassEmbeddings(
        dept: widget.student.course,
        batch: widget.student.year,
        branch: widget.student.branch,
      );
      if (mounted) {
        setState(() => _statusMessage = 'Sync Complete! Offline Ready.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class data synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Sync Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Student'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Camera Preview (Top Half)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    Center(
                      child: ClipRect(
                        child: SizedOverflowBox(
                          size: Size.infinite,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width:
                                  _cameraController!.value.previewSize!.height,
                              height:
                                  _cameraController!.value.previewSize!.width,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          _statusMessage ?? 'Initializing Camera...',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                  // Overlay Box
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _result == null
                              ? Colors.white.withOpacity(0.5)
                              : (_result!.isMatch ? Colors.green : Colors.red),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  if (_isVerifying)
                    const Center(child: CircularProgressIndicator()),

                  if (_result != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _result!.isMatch ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _result!.message +
                              ' (${(_result!.similarity * 100).toStringAsFixed(1)}%)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Student Info (Bottom Half)
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: widget.student.photoUrl.isNotEmpty
                            ? NetworkImage(
                                widget.student.photoUrl,
                              ) // TODO: Use R2 loader
                            : null,
                        radius: 30,
                        child: widget.student.photoUrl.isEmpty
                            ? Text(widget.student.rollNo.substring(0, 2))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.student.rollNo,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            // ADDED: Sync Indicator/Button logic could go here or in AppBar
                          ],
                        ),
                      ),
                      // Sync Button
                      IconButton(
                        icon: const Icon(Icons.sync, color: Colors.blue),
                        onPressed: _syncEmbeddings,
                        tooltip: 'Sync Class Data',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Check if student needs face registration (Only if NO embeddings AND NO passport photo)
                  if ((widget.student.embeddings == null ||
                          widget.student.embeddings!.isEmpty) &&
                      widget.student.photoUrl.isEmpty)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No face data found. Please register first.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Navigate to multi-angle registration
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MultiAngleFaceRegistrationScreen(
                                        student: widget.student,
                                      ),
                                ),
                              );

                              // If registration successful, refresh the screen
                              if (result == true && mounted) {
                                setState(() {
                                  _statusMessage =
                                      'Registration complete! You can now verify.';
                                });
                              }
                            },
                            icon: const Icon(Icons.face_retouching_natural),
                            label: const Text('REGISTER FACE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _captureAndVerify,
                        icon: const Icon(Icons.face),
                        label: const Text('VERIFY IDENTITY'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (_result != null && _result!.isMatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            // Navigate to success/check-in complete
                            Navigator.pop(context);
                          },
                          child: const Text('CONFIRM CHECK-IN'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
