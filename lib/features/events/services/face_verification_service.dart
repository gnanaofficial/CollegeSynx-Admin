import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

// DEPRECATED: Use FaceMatchingService instead.
// This service was a mock that always returned 'verified'.

enum VerificationStatus { none, scanning, verified, failed, error }

class FaceVerificationService {
  Future<VerificationStatus> verifyFace(
    XFile capturedImage,
    String storedImagePath,
  ) async {
    throw UnimplementedError(
      "This service is deprecated. Use FaceMatchingService.",
    );
  }
}

final faceVerificationServiceProvider = Provider(
  (ref) => FaceVerificationService(),
);
