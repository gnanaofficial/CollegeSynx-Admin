import 'package:flutter/material.dart';

/// Represents the different face pose angles for multi-angle registration
enum FacePoseType {
  front,
  leftProfile,
  rightProfile;

  /// Display name for the pose
  String get displayName {
    switch (this) {
      case FacePoseType.front:
        return 'Front Face';
      case FacePoseType.leftProfile:
        return 'Left Profile';
      case FacePoseType.rightProfile:
        return 'Right Profile';
    }
  }

  /// Instruction text to guide user
  String get instruction {
    switch (this) {
      case FacePoseType.front:
        return 'Keep your face inside the frame';
      case FacePoseType.leftProfile:
        return 'Turn your head to the left';
      case FacePoseType.rightProfile:
        return 'Turn your head to the right';
    }
  }

  /// Secondary instruction for additional guidance
  String get secondaryInstruction {
    switch (this) {
      case FacePoseType.front:
        return 'Look straight at the camera';
      case FacePoseType.leftProfile:
        return 'Rotate your face about 45 degrees';
      case FacePoseType.rightProfile:
        return 'Rotate your face about 45 degrees';
    }
  }

  /// Icon representing the pose
  IconData get icon {
    switch (this) {
      case FacePoseType.front:
        return Icons.face;
      case FacePoseType.leftProfile:
        return Icons.rotate_left;
      case FacePoseType.rightProfile:
        return Icons.rotate_right;
    }
  }

  /// Expected head Euler angle Y range (in degrees)
  /// Negative = left rotation, Positive = right rotation
  (double min, double max) get expectedAngleRange {
    switch (this) {
      case FacePoseType.front:
        return (-15.0, 15.0); // Allow slight deviation
      case FacePoseType.leftProfile:
        return (-60.0, -30.0); // Left rotation
      case FacePoseType.rightProfile:
        return (30.0, 60.0); // Right rotation
    }
  }

  /// Step number in the registration flow (1-indexed)
  int get stepNumber {
    switch (this) {
      case FacePoseType.front:
        return 1;
      case FacePoseType.leftProfile:
        return 2;
      case FacePoseType.rightProfile:
        return 3;
    }
  }

  /// Total number of steps
  static int get totalSteps => 3;

  /// Get all poses in registration order
  static List<FacePoseType> get registrationOrder => [
    FacePoseType.front,
    FacePoseType.leftProfile,
    FacePoseType.rightProfile,
  ];
}

/// Quality check result for face capture
class FaceQualityCheck {
  final bool isGoodLighting;
  final bool isFaceCentered;
  final bool isFaceSizeOk;
  final bool areEyesOpen;
  final bool isPoseCorrect;
  final String? errorMessage;

  const FaceQualityCheck({
    required this.isGoodLighting,
    required this.isFaceCentered,
    required this.isFaceSizeOk,
    required this.areEyesOpen,
    required this.isPoseCorrect,
    this.errorMessage,
  });

  /// Check if all quality criteria are met
  bool get isValid =>
      isGoodLighting &&
      isFaceCentered &&
      isFaceSizeOk &&
      areEyesOpen &&
      isPoseCorrect;

  /// Get user-friendly error message
  String get feedbackMessage {
    if (errorMessage != null) return errorMessage!;
    if (!isGoodLighting) return 'Insufficient lighting';
    if (!isFaceCentered) return 'Center your face in the frame';
    if (!isFaceSizeOk) return 'Move closer to the camera';
    if (!areEyesOpen) return 'Please open your eyes';
    if (!isPoseCorrect) return 'Adjust your head position';
    return 'Perfect! Hold still...';
  }

  factory FaceQualityCheck.failed(String message) => FaceQualityCheck(
    isGoodLighting: false,
    isFaceCentered: false,
    isFaceSizeOk: false,
    areEyesOpen: false,
    isPoseCorrect: false,
    errorMessage: message,
  );

  factory FaceQualityCheck.passed() => const FaceQualityCheck(
    isGoodLighting: true,
    isFaceCentered: true,
    isFaceSizeOk: true,
    areEyesOpen: true,
    isPoseCorrect: true,
  );
}
