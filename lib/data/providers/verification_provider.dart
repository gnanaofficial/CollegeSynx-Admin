import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/face_detection_service.dart';
import '../../core/services/face_recognition_service.dart';
import '../../core/services/verification_service.dart';
import '../services/offline_cache_service.dart';
import 'student_provider.dart';

final faceDetectionProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final faceRecognitionProvider = Provider<FaceRecognitionService>((ref) {
  return FaceRecognitionService();
});

final offlineCacheProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

final verificationServiceProvider = Provider<VerificationService>((ref) {
  final studentRepo = ref.watch(studentRepositoryProvider);
  final faceDetection = ref.watch(faceDetectionProvider);
  final faceRecognition = ref.watch(faceRecognitionProvider);
  final offlineCache = ref.watch(offlineCacheProvider);

  return VerificationService(
    studentRepo,
    faceDetection,
    faceRecognition,
    offlineCache,
  );
});
