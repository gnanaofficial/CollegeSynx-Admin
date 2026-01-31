import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/verification_provider.dart';
import '../../../domain/entities/student.dart';
import '../../verification/presentation/verification_result_widget.dart';

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final Student student;

  const FaceEnrollmentScreen({super.key, required this.student});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  CameraController? _controller;
  bool _isInit = false;
  XFile? _capturedImage;
  bool _isEnrolling = false;
  String? _statusMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    // Prefer front camera
    final frontCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() => _isInit = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndEnroll() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();

      setState(() {
        _capturedImage = image;
        _statusMessage = "Analyzing Face...";
        _isEnrolling = true;
      });

      // 1. Quick Local Check (for visual feedback)
      final faceService = ref.read(faceDetectionProvider);
      final face = await faceService.detectSingleFace(image.path);

      if (face == null) {
        if (mounted) {
          setState(() {
            _isEnrolling = false;
            _statusMessage = "No face detected! Please try again.";
            _success = false;
          });
        }
        return;
      }

      // Face found! Update UI to show Green before proceeding (UX)
      setState(() {
        _statusMessage = "Face OK! Registering...";
      });

      // 2. Perform Enrollment (Generate Embedding & Save)
      final result = await ref
          .read(verificationServiceProvider)
          .enrollStudent(student: widget.student, livePhoto: image);

      if (mounted) {
        setState(() {
          _isEnrolling = false;
          _success = result.isMatch;
          _statusMessage = result.message;
        });

        if (_success) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    } catch (e) {
      print('Face enrollment error: $e'); // Debug logging
      if (mounted) {
        setState(() {
          _isEnrolling = false;
          _success = false;
          _statusMessage = "Error: ${e.toString()}";
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _capturedImage = null;
      _statusMessage = null;
      _success = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Face Registration")),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  "Registering: ${widget.student.name}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Please ensure good lighting and verify the face is clearly visible.",
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Camera Area
          Expanded(
            child: Stack(
              children: [
                if (_capturedImage == null)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: CameraPreview(_controller!),
                  )
                else
                  Image.file(
                    File(_capturedImage!.path),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),

                // Overlay Guidelines (Dynamic Color)
                if (_capturedImage == null || _isEnrolling)
                  Center(
                    child: Container(
                      width: 280,
                      height: 350,
                      decoration: BoxDecoration(
                        border: Border.all(
                          // Turn Green if Success or Enrolling (optimistic)
                          color: (_success || _isEnrolling)
                              ? Colors.green
                              : Colors.white.withOpacity(0.5),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(150),
                      ),
                    ),
                  ),

                // Loading / Status Overlay
                if (_isEnrolling || _statusMessage != null)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEnrolling)
                              const CircularProgressIndicator()
                            else if (_success)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 48,
                              )
                            else
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 48,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isEnrolling && !_success) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _retry,
                                child: const Text("Try Again"),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          if (_capturedImage == null)
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.large(
                    onPressed: _captureAndEnroll,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 32,
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
