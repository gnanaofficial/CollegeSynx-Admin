import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/student_repository.dart';
import 'face_detection_service.dart';
import 'face_recognition_service.dart';
import '../../data/services/offline_cache_service.dart';
import '../../data/models/student_embedding.dart';

class VerificationResult {
  final bool isMatch;
  final double similarity; // 0.0 to 1.0 (higher is better match)
  final String message;
  final bool isError;

  VerificationResult({
    required this.isMatch,
    required this.similarity,
    required this.message,
    this.isError = false,
  });

  factory VerificationResult.match(double score) => VerificationResult(
    isMatch: true,
    similarity: score,
    message: 'Identity Verified',
  );

  factory VerificationResult.noMatch(double score) => VerificationResult(
    isMatch: false,
    similarity: score,
    message: 'Identity Verification Failed',
  );

  factory VerificationResult.error(String msg) => VerificationResult(
    isMatch: false,
    similarity: 0.0,
    message: msg,
    isError: true,
  );
}

class VerificationService {
  final StudentRepository _studentRepo;
  final FaceDetectionService _faceDetection;
  final FaceRecognitionService _faceRecognition;
  final OfflineCacheService _offlineCache;

  // Verification Threshold
  // Tuned for high accuracy: 0.75
  // Verification Threshold
  // Tuned for balance: 0.60 (Standard for MobileFaceNet)
  static const double matchThreshold = 0.60;

  VerificationService(
    this._studentRepo,
    this._faceDetection,
    this._faceRecognition,
    this._offlineCache,
  );

  /// Initialize services (Hive)
  Future<void> initialize() async {
    await _offlineCache.initialize();
  }

  /// Sync Embeddings for a class (Download & Cache)
  Future<void> syncClassEmbeddings({
    required String dept,
    required String batch,
    required String branch,
  }) async {
    try {
      // 1. Fetch all students from Firestore
      final result = await _studentRepo.getStudentsByBranch(
        dept: dept,
        batch: batch,
        branch: branch,
      );

      result.fold((error) => throw error, (students) async {
        // 2. Convert valid students to embeddings
        final List<StudentEmbedding> embeddingsToCache = [];

        for (final student in students) {
          if (student.embeddings != null && student.embeddings!.isNotEmpty) {
            embeddingsToCache.add(
              StudentEmbedding.fromEmbeddings(
                rollNo: student.rollNo,
                name: student.name,
                dept: student.course, // Assuming course is dept
                batch: student.year,
                branch: student.branch,
                embeddings: student.embeddings!,
              ),
            );
          } else if (student.embedding != null &&
              student.embedding!.isNotEmpty) {
            // Support legacy single embedding
            embeddingsToCache.add(
              StudentEmbedding.fromEmbeddings(
                rollNo: student.rollNo,
                name: student.name,
                dept: student.course,
                batch: student.year,
                branch: student.branch,
                embeddings: [student.embedding!],
              ),
            );
          }
        }

        // 3. Save to Hive
        await _offlineCache.cacheEmbeddings(embeddingsToCache);
      });
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  // Helper to sync one student
  // ...

  // Revised verifyStudent to use _offlineCache

  /// Verify a live captured image against the student's stored photo
  Future<VerificationResult> verifyStudent({
    required Student student,
    required XFile livePhoto,
  }) async {
    try {
      List<List<double>> storedEmbeddings = [];
      dynamic liveCropped;

      // 1. CHECK OFFLINE CACHE (Fastest Path) ⚡
      // This enables verification even if the passed 'Student' object doesn't have embeddings loaded
      // (e.g. from a barcode scan that only returned basic info)
      final cachedEmbedding = _offlineCache.getEmbedding(student.rollNo);

      if (cachedEmbedding != null) {
        storedEmbeddings = cachedEmbedding.embeddings;

        // Process only live photo
        liveCropped = await _processImage(livePhoto.path);
        if (liveCropped == null) {
          return VerificationResult(
            isMatch: false,
            similarity: 0.0,
            message: 'No face detected in live photo',
          );
        }
      }
      // 2. CHECK PASSED STUDENT OBJECT (Fast Path) 🚀
      else if (student.embeddings != null && student.embeddings!.isNotEmpty) {
        storedEmbeddings = student.embeddings!;

        // Process only live photo
        liveCropped = await _processImage(livePhoto.path);
        if (liveCropped == null) {
          return VerificationResult(
            isMatch: false,
            similarity: 0.0,
            message: 'No face detected in live photo',
          );
        }
      } else if (student.embedding != null && student.embedding!.isNotEmpty) {
        // Fallback to legacy single embedding
        storedEmbeddings = [student.embedding!];

        // Process only live photo
        liveCropped = await _processImage(livePhoto.path);
        if (liveCropped == null) {
          return VerificationResult(
            isMatch: false,
            similarity: 0.0,
            message: 'No face detected in live photo',
          );
        }
      } else {
        // 3. DOWNLOAD & COMPUTE (Slow Path - First Run) 🐢
        final storedPhotoResult = await _studentRepo.downloadStudentPhoto(
          student.photoUrl,
        );

        // Handle download result manually to exit early on error
        if (storedPhotoResult.isLeft()) {
          final error = storedPhotoResult.fold((l) => l, (r) => null);
          return VerificationResult.error(
            'Failed to download stored photo: $error',
          );
        }

        final storedBytes = storedPhotoResult.getOrElse(() => Uint8List(0));

        final tempDir = await getTemporaryDirectory();

        // Write stored and live files
        final storedFile = File('${tempDir.path}/stored_${student.rollNo}.jpg');
        await storedFile.writeAsBytes(storedBytes);

        final liveFile = File(livePhoto.path);

        // Parallel Process
        final results = await Future.wait([
          _processImage(storedFile.path),
          _processImage(liveFile.path),
        ]);

        final storedCropped = results[0];
        liveCropped = results[1];

        if (storedCropped == null) {
          return VerificationResult.error('No face detected in stored photo');
        }
        if (liveCropped == null) {
          return VerificationResult(
            isMatch: false,
            similarity: 0.0,
            message: 'No face detected in live photo',
          );
        }

        final storedEmb = await _faceRecognition.generateEmbedding(
          storedCropped,
        );
        storedEmbeddings = [storedEmb];

        // 3. UPDATE CACHE 💾 (legacy single embedding)
        await _studentRepo.updateStudentEmbedding(student.rollNo, storedEmb);
      }

      // 4. COMPARE against all stored embeddings
      final liveEmb = await _faceRecognition.generateEmbedding(liveCropped);

      // Calculate similarity with each stored embedding and use the MAXIMUM
      double maxSimilarity = 0.0;
      for (final storedEmb in storedEmbeddings) {
        final similarity = _faceRecognition.compareEmbeddings(
          storedEmb,
          liveEmb,
        );
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
        }
      }

      // Logic for result
      if (maxSimilarity >= matchThreshold) {
        return VerificationResult.match(maxSimilarity);
      } else {
        return VerificationResult.noMatch(maxSimilarity);
      }
    } catch (e) {
      return VerificationResult.error('Verification error: $e');
    }
  }

  /// Enroll a student by capturing a live photo and saving their embedding
  Future<VerificationResult> enrollStudent({
    required Student student,
    required XFile livePhoto,
  }) async {
    try {
      // 1. Process Live Photo
      final liveCropped = await _processImage(livePhoto.path);

      if (liveCropped == null) {
        return VerificationResult(
          isMatch: false,
          similarity: 0.0,
          message:
              'No face detected. Please ensure good lighting and face camera.',
        );
      }

      // 2. Generate Embedding
      final embedding = await _faceRecognition.generateEmbedding(liveCropped);

      // 3. Save to Firestore
      final updateResult = await _studentRepo.updateStudentEmbedding(
        student.rollNo,
        embedding,
      );

      return updateResult.fold(
        (error) =>
            VerificationResult.error('Failed to save enrollment: $error'),
        (_) => VerificationResult(
          isMatch: true,
          similarity: 1.0,
          message: 'Enrollment Successful',
        ),
      );
    } catch (e) {
      return VerificationResult.error('Enrollment error: $e');
    }
  }

  /// Helper to detect and crop face from a file path
  Future<dynamic> _processImage(String path) async {
    final face = await _faceDetection.detectSingleFace(path);
    if (face == null) return null;
    return await _faceDetection.cropFace(path, face);
  }

  // Helper to calculate similarity (exposed for testing/tuning)
  double calculateSimilarity(List<double> emb1, List<double> emb2) {
    return _faceRecognition.compareEmbeddings(emb1, emb2);
  }
}
