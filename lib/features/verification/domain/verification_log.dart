import 'package:equatable/equatable.dart';

enum VerificationResult { success, failed, manualOverride }

class VerificationLog extends Equatable {
  final String id;
  final String studentId;
  final String eventId;
  final DateTime timestamp;
  final VerificationResult result;
  final double confidenceScore;
  final String? failureReason;
  final String? overrideReason;

  const VerificationLog({
    required this.id,
    required this.studentId,
    required this.eventId,
    required this.timestamp,
    required this.result,
    this.confidenceScore = 0.0,
    this.failureReason,
    this.overrideReason,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    eventId,
    timestamp,
    result,
    confidenceScore,
    failureReason,
    overrideReason,
  ];

  // For storage later
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'result': result.toString(),
      'confidenceScore': confidenceScore,
      'failureReason': failureReason,
      'overrideReason': overrideReason,
    };
  }

  factory VerificationLog.fromJson(Map<String, dynamic> json) {
    return VerificationLog(
      id: json['id'],
      studentId: json['studentId'],
      eventId: json['eventId'],
      timestamp: DateTime.parse(json['timestamp']),
      result: VerificationResult.values.firstWhere(
        (e) => e.toString() == json['result'],
      ),
      confidenceScore: json['confidenceScore'],
      failureReason: json['failureReason'],
      overrideReason: json['overrideReason'],
    );
  }
}
