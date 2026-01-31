import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/verification_provider.dart';
import '../../../data/providers/student_provider.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/face_pose_type.dart';
import 'widgets/face_registration_widgets.dart';

class MultiAngleFaceRegistrationScreen extends ConsumerStatefulWidget {
  final Student student;

  const MultiAngleFaceRegistrationScreen({super.key, required this.student});

  @override
  ConsumerState<MultiAngleFaceRegistrationScreen> createState() =>
      _MultiAngleFaceRegistrationScreenState();
}

class _MultiAngleFaceRegistrationScreenState
    extends ConsumerState<MultiAngleFaceRegistrationScreen> {
  CameraController? _controller;
  bool _isInit = false;
  bool _useFrontCamera = true;
  int _currentStepIndex = 0;
  List<XFile> _capturedImages = [];
  bool _isProcessing = false;
  String? _feedbackMessage;
  Timer? _detectionTimer;
  String? _initError;

  FacePoseType get _currentPose =>
      FacePoseType.registrationOrder[_currentStepIndex];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initError = 'No camera found';
            _isInit = false;
          });
        }
        return;
      }

      // Use front or back camera based on selection
      final camera = cameras.firstWhere(
        (c) =>
            c.lensDirection ==
            (_useFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset
            .medium, // Changed from high to medium for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Add small delay to ensure camera is fully ready
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _isInit = true;
          _initError = null;
        });
        print('Camera initialized successfully: ${camera.lensDirection}');
        // Disable real-time detection for better performance
        // _startRealtimeDetection();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _initError = 'Camera error: ${e.toString()}';
          _isInit = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      // Cancel detection timer
      _detectionTimer?.cancel();

      // Dispose current controller
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      // Update state
      setState(() {
        _isInit = false;
        _useFrontCamera = !_useFrontCamera;
        _initError = null;
      });

      // Wait a bit before reinitializing
      await Future.delayed(const Duration(milliseconds: 500));

      // Reinitialize camera
      await _initCamera();
    } catch (e) {
      print('Camera switch error: $e');
      if (mounted) {
        setState(() {
          _initError = 'Failed to switch camera: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentPose() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _feedbackMessage = 'Capturing...';
    });

    try {
      final image = await _controller!.takePicture();

      // Validate the captured image
      final faceService = ref.read(faceDetectionProvider);
      final face = await faceService.detectSingleFace(image.path);

      if (face == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _feedbackMessage = 'No face detected! Please try again.';
          });
        }
        await File(image.path).delete();
        return;
      }

      // Check quality
      final quality = await faceService.checkFaceQuality(
        face,
        image.path,
        _currentPose,
      );

      if (!quality.isValid) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _feedbackMessage = quality.feedbackMessage;
          });
        }
        await File(image.path).delete();

        // Show error dialog
        _showErrorDialog(quality.feedbackMessage);
        return;
      }

      // Success! Add to captured images
      _capturedImages.add(image);

      // Move to next step or complete registration
      if (_currentStepIndex < FacePoseType.totalSteps - 1) {
        setState(() {
          _currentStepIndex++;
          _isProcessing = false;
          _feedbackMessage = null;
        });
      } else {
        // All poses captured, proceed to enrollment
        await _completeRegistration();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _feedbackMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _completeRegistration() async {
    setState(() {
      _isProcessing = true;
      _feedbackMessage = 'Processing registration...';
    });

    try {
      // Generate embeddings for all captured poses
      final faceDetection = ref.read(faceDetectionProvider);
      final faceRecognition = ref.read(faceRecognitionProvider);

      List<List<double>> embeddings = [];
      Map<String, dynamic> metadata = {
        'capturedAt': DateTime.now().toIso8601String(),
        'poses': [],
      };

      for (int i = 0; i < _capturedImages.length; i++) {
        final image = _capturedImages[i];
        final pose = FacePoseType.registrationOrder[i];

        // Detect and crop face
        final face = await faceDetection.detectSingleFace(image.path);
        if (face == null) continue;

        final croppedFace = await faceDetection.cropFace(image.path, face);
        if (croppedFace == null) continue;

        // Generate embedding
        final embedding = await faceRecognition.generateEmbedding(croppedFace);
        embeddings.add(embedding);

        // Store metadata
        metadata['poses'].add({
          'type': pose.name,
          'angle': faceDetection.getHeadPoseAngle(face),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      if (embeddings.length != 3) {
        throw Exception('Failed to generate all embeddings');
      }

      // Save to Firestore
      final studentRepo = ref.read(studentRepositoryProvider);
      final result = await studentRepo.updateStudentEmbeddings(
        widget.student.rollNo,
        embeddings,
        metadata,
      );

      result.fold(
        (error) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _feedbackMessage = 'Failed to save: $error';
            });
            _showErrorDialog('Failed to save registration: $error');
          }
        },
        (_) {
          if (mounted) {
            // Show success dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => RegistrationSuccessDialog(
                message: 'Registration Successful!',
                onComplete: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to previous screen
                },
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _feedbackMessage = 'Error: $e';
        });
        _showErrorDialog('Registration failed: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _currentStepIndex = 0;
      _capturedImages.clear();
      _isProcessing = false;
      _feedbackMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Face Registration',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: _initError != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initError!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _initError = null);
                        _initCamera();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Face Registration',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Camera switch button
          IconButton(
            icon: Icon(
              _useFrontCamera ? Icons.camera_front : Icons.camera_rear,
              color: Colors.white,
            ),
            onPressed: _isProcessing ? null : _switchCamera,
            tooltip: 'Switch Camera',
          ),
          if (_capturedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _retry,
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: Column(
        children: [
          // Student Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade900,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  widget.student.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.rollNo,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                RegistrationStepIndicator(
                  currentStep: _currentStepIndex,
                  totalSteps: FacePoseType.totalSteps,
                ),
              ],
            ),
          ),

          // Camera Preview
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview with proper aspect ratio (no stretching)
                  if (_controller != null &&
                      _controller!.value.isInitialized &&
                      _isInit)
                    Center(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height:
                                  MediaQuery.of(context).size.width *
                                  _controller!.value.aspectRatio,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),

                  // Face frame overlay
                  if (_isInit)
                    Center(
                      child: Container(
                        width: 280,
                        height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                  // Pose instruction overlay
                  if (_isInit)
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _currentPose.icon,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentPose.instruction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Step ${_currentStepIndex + 1} of ${FacePoseType.totalSteps}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            if (_feedbackMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _feedbackMessage!,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Capture hint
                  if (_isInit)
                    Positioned(
                      bottom: 100,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Position your face in the frame and tap the camera button',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ), // Capture Button
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: _isProcessing ? null : _captureCurrentPose,
                  backgroundColor: _isProcessing ? Colors.grey : Colors.green,
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: Colors.white,
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
