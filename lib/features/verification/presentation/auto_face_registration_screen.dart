import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../domain/entities/student.dart';
import '../../../data/providers/verification_provider.dart';
import '../../../data/providers/student_provider.dart';
import 'package:image/image.dart' as img;

/// Manual Face Registration Screen
/// Replaces the automated flow with a stable, manual capture process
/// similar to the Event Scanner / Student Verification flow.
class AutoFaceRegistrationScreen extends ConsumerStatefulWidget {
  final Student student;

  const AutoFaceRegistrationScreen({super.key, required this.student});

  @override
  ConsumerState<AutoFaceRegistrationScreen> createState() =>
      _AutoFaceRegistrationScreenState();
}

class _AutoFaceRegistrationScreenState
    extends ConsumerState<AutoFaceRegistrationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Initializing camera...';
  int _captureCount = 0;
  final int _requiredCaptures = 3;
  bool _faceDetected = false;
  List<List<double>> _collectedEmbeddings = [];

  @override
  void initState() {
    super.initState();
    // Add small delay to ensure previous camera session is fully released
    Future.delayed(const Duration(milliseconds: 500), _initializeCamera);
  }

  Future<void> _initializeCamera({bool retry = true}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _statusMessage = 'No camera found');
        return;
      }

      // 1. Select Front Camera by default
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // 2. Initialize Controller (No audio, medium resolution for performance)
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Ready. Align face and tap Capture.';
        });
      }
    } catch (e) {
      print('Camera init error: $e');
      if (retry && mounted) {
        // Retry once after a delay if failed (common for broken pipe/busy errors)
        setState(() => _statusMessage = 'Camera busy, retrying...');
        await Future.delayed(const Duration(seconds: 1));
        _initializeCamera(retry: false);
      } else if (mounted) {
        setState(
          () => _statusMessage = 'Camera Error. Please restart app.\n$e',
        );
      }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
    });

    try {
      // 1. Capture Image
      final XFile image = await _cameraController!.takePicture();

      // 2. Detect Face
      final faceDetectionService = ref.read(faceDetectionProvider);
      final face = await faceDetectionService.detectSingleFace(image.path);

      if (face == null) {
        _showMessage('No face detected. Please ensure good lighting.');
        await File(image.path).delete();
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Crop Face
      // Note: We use the service's crop method if available, or do it manually if logic is local.
      // Based on previous reads, the service might not return 'img.Image' directly public.
      // Let's rely on local crop logic that worked in the previous 'auto' file to be safe,
      // OR use the service if we are sure.
      // The user's prompt says "refer the events registered... verify the image".
      // I will use robust local cropping to ensure we get the right data for embedding.

      final bytes = await File(image.path).readAsBytes();
      final fullImage = img.decodeImage(bytes);

      if (fullImage != null) {
        final bbox = face.boundingBox;

        // Basic Size Check
        if (bbox.width < 100 || bbox.height < 100) {
          _showMessage('Face too small. Move closer.');
          await File(image.path).delete();
          setState(() => _isProcessing = false);
          return;
        }

        // Crop
        final faceImage = img.copyCrop(
          fullImage,
          x: bbox.left.toInt().clamp(0, fullImage.width),
          y: bbox.top.toInt().clamp(0, fullImage.height),
          width: bbox.width.toInt().clamp(
            1,
            fullImage.width - bbox.left.toInt(),
          ),
          height: bbox.height.toInt().clamp(
            1,
            fullImage.height - bbox.top.toInt(),
          ),
        );

        // 4. Generate Embedding
        final faceRecognitionService = ref.read(faceRecognitionProvider);
        final embedding = await faceRecognitionService.generateEmbedding(
          faceImage,
        );

        _collectedEmbeddings.add(embedding);
        _captureCount++;

        // Next Step Prompt
        String nextMsg = '';
        if (_captureCount == 1) nextMsg = '2/3: Turn Head Slightly LEFT';
        if (_captureCount == 2) nextMsg = '3/3: Turn Head Slightly RIGHT';
        if (_captureCount >= 3) nextMsg = 'Finalizing Registration...';

        _showMessage(nextMsg, isError: false);

        // Check Completion
        if (_captureCount >= _requiredCaptures) {
          // Average the embeddings to create a single stable identity
          final averagedEmbedding = _calculateAverageEmbedding(
            _collectedEmbeddings,
          );
          await _uploadEmbedding(averagedEmbedding);
        }
      }

      await File(image.path).delete();
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted && _captureCount < _requiredCaptures) {
        setState(() => _isProcessing = false);
      }
    }
  }

  List<double> _calculateAverageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    int dimension = embeddings[0].length;
    List<double> avg = List.filled(dimension, 0.0);

    for (var emb in embeddings) {
      for (int i = 0; i < dimension; i++) {
        avg[i] += emb[i];
      }
    }

    for (int i = 0; i < dimension; i++) {
      avg[i] /= embeddings.length;
    }
    return avg;
  }

  Future<void> _uploadEmbedding(List<double> embedding) async {
    setState(() => _statusMessage = 'Saving biometric profile...');

    try {
      final repo = ref.read(studentRepositoryProvider);

      // Update with Single Averaged Embedding
      final result = await repo.updateStudentEmbedding(
        widget.student.rollNo,
        embedding,
      );

      result.fold((e) => _showMessage('Save Failed: $e'), (_) {
        if (mounted) {
          _showMessage('Registration Successful!', isError: false);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      });
    } catch (e) {
      _showMessage('Upload Error: $e');
    }
  }

  void _showMessage(String msg, {bool isError = true}) {
    if (!mounted) return;
    setState(() => _statusMessage = msg);
    if (!isError) {
      // Optional visual feedback
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Camera Status Loading
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusMessage, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // 2. Main Layout (Camera + Controls)
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register Face'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Camera Preview Area (Takes most space)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The camera preview widget
                  CameraPreview(_cameraController!),

                  // Face Guide Overlay
                  Center(
                    child: Container(
                      width: 280,
                      height: 350,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _faceDetected
                              ? Colors.green
                              : Colors.white.withOpacity(0.6),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(150), // Oval shape
                      ),
                    ),
                  ),

                  // Processing Overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controls Area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Progress Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_requiredCaptures, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _captureCount
                              ? Colors.green
                              : Colors.grey[300],
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Capture Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _captureAndProcess,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _captureCount < _requiredCaptures
                            ? 'CAPTURE PHOTO'
                            : 'FINISHING...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
