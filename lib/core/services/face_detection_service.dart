import 'dart:io';

import 'package:flutter/foundation.dart'; // For compute
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:ui'; // For Offset
import '../../domain/face_pose_type.dart';

class FaceDetectionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Detect faces in an image (from file path)
  Future<List<Face>> detectFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await _faceDetector.processImage(inputImage);
  }

  /// Detect faces from InputImage (Streaming)
  Future<List<Face>> detectFacesFromInputImage(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  /// Detect single face (returns face closest to IMAGE CENTER)
  Future<Face?> detectSingleFace(String imagePath) async {
    final faces = await detectFaces(imagePath);
    if (faces.isEmpty) return null;

    try {
      // Decode image to get dimensions for center calculation
      final bytes = await File(imagePath).readAsBytes();
      // Run heavy decoding in background isolate
      final image = await compute(img.decodeImage, bytes);

      if (image != null) {
        final centerX = image.width / 2.0;
        final centerY = image.height / 2.0;

        // Sort by distance to center (Ascending: Closest first)
        faces.sort((a, b) {
          final distA = _getDistSq(a.boundingBox.center, centerX, centerY);
          final distB = _getDistSq(b.boundingBox.center, centerX, centerY);
          return distA.compareTo(distB);
        });

        return faces.first;
      }
    } catch (e) {
      // Ignore error and fallback to size-based sorting
      print("Error sorting faces by center: $e");
    }

    // Fallback: Sort by bounding box area (largest face first)
    faces.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );

    return faces.first;
  }

  double _getDistSq(Offset p, double cx, double cy) {
    return (p.dx - cx) * (p.dx - cx) + (p.dy - cy) * (p.dy - cy);
  }

  /// Validate if face pose matches expected pose type
  bool validateFacePose(Face face, FacePoseType poseType) {
    final headEulerAngleY = face.headEulerAngleY;
    if (headEulerAngleY == null) return false;

    final (minAngle, maxAngle) = poseType.expectedAngleRange;
    return headEulerAngleY >= minAngle && headEulerAngleY <= maxAngle;
  }

  /// Check face quality for registration
  Future<FaceQualityCheck> checkFaceQuality(
    Face face,
    String imagePath,
    FacePoseType expectedPose,
  ) async {
    try {
      // 1. Check if pose is correct
      final isPoseCorrect = validateFacePose(face, expectedPose);

      // 2. Check if eyes are open (liveness check)
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      final areEyesOpen = (leftEyeOpen > 0.3 && rightEyeOpen > 0.3);

      // 3. Check face size (minimum 100x100 pixels)
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final isFaceSizeOk = faceWidth >= 100 && faceHeight >= 100;

      // 4. Check if face is centered
      final bytes = await File(imagePath).readAsBytes();
      final image = await compute(img.decodeImage, bytes);
      bool isFaceCentered = false;

      if (image != null) {
        final centerX = image.width / 2.0;
        final centerY = image.height / 2.0;
        final faceCenterX = face.boundingBox.center.dx;
        final faceCenterY = face.boundingBox.center.dy;

        // Allow 30% deviation from center
        final maxDeviationX = image.width * 0.3;
        final maxDeviationY = image.height * 0.3;

        isFaceCentered =
            (faceCenterX - centerX).abs() < maxDeviationX &&
            (faceCenterY - centerY).abs() < maxDeviationY;
      }

      // 5. Check lighting (estimate from image brightness)
      bool isGoodLighting = true;
      if (image != null) {
        // Sample brightness from face region
        final x = face.boundingBox.left.toInt().clamp(0, image.width - 1);
        final y = face.boundingBox.top.toInt().clamp(0, image.height - 1);
        final w = face.boundingBox.width.toInt().clamp(1, image.width - x);
        final h = face.boundingBox.height.toInt().clamp(1, image.height - y);

        // Sample a few pixels to estimate brightness
        double totalBrightness = 0;
        int sampleCount = 0;
        final step = 10; // Sample every 10 pixels

        for (int dy = 0; dy < h; dy += step) {
          for (int dx = 0; dx < w; dx += step) {
            final px = x + dx;
            final py = y + dy;
            if (px < image.width && py < image.height) {
              final pixel = image.getPixel(px, py);
              // Calculate luminance
              final brightness =
                  (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
              totalBrightness += brightness;
              sampleCount++;
            }
          }
        }

        if (sampleCount > 0) {
          final avgBrightness = totalBrightness / sampleCount;
          // Good lighting: brightness between 0.2 and 0.8
          isGoodLighting = avgBrightness >= 0.2 && avgBrightness <= 0.8;
        }
      }

      return FaceQualityCheck(
        isGoodLighting: isGoodLighting,
        isFaceCentered: isFaceCentered,
        isFaceSizeOk: isFaceSizeOk,
        areEyesOpen: areEyesOpen,
        isPoseCorrect: isPoseCorrect,
      );
    } catch (e) {
      print('Error checking face quality: $e');
      return FaceQualityCheck.failed('Quality check failed');
    }
  }

  /// Get current head pose angle (for real-time feedback)
  double? getHeadPoseAngle(Face face) {
    return face.headEulerAngleY;
  }

  /// Crop face from image with padding
  Future<img.Image?> cropFace(String imagePath, Face face) async {
    final bytes = await File(imagePath).readAsBytes();
    final bbox = face.boundingBox;

    // Use compute to decode and crop in background
    return await compute(_cropFaceTask, {
      'bytes': bytes,
      'x': bbox.left.toInt(),
      'y': bbox.top.toInt(),
      'width': bbox.width.toInt(),
      'height': bbox.height.toInt(),
    });
  }

  static img.Image? _cropFaceTask(Map<String, dynamic> args) {
    final bytes = args['bytes'] as Uint8List;
    final x = args['x'] as int;
    final y = args['y'] as int;
    final width = args['width'] as int;
    final height = args['height'] as int;

    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // For now, consistent cropping is key for FaceNet
    return img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  void dispose() {
    _faceDetector.close();
  }
}
