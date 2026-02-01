import 'package:equatable/equatable.dart';

class DisciplineCase extends Equatable {
  final String id;
  final String studentId;
  final String category; // Academic, IT, Administrative
  final String subCategory;
  final String subject; // Short title e.g. "Missing Grade"
  final String description;
  final String severity; // Normal, High
  final DateTime timestamp;
  final String? proofImagePath;
  final String reportedBy;
  final int? pointsDeducted;
  final String? reporterId;

  const DisciplineCase({
    required this.id,
    required this.studentId,
    required this.category,
    this.subCategory = 'General', // Default for migration safety
    required this.subject,
    this.description = '',
    this.severity = 'Normal',
    required this.timestamp,
    this.proofImagePath,
    required this.reportedBy,
    this.pointsDeducted,
    this.reporterId,
  });

  DisciplineCase copyWith({
    String? id,
    String? studentId,
    String? category,
    String? subCategory,
    String? subject,
    String? description,
    String? severity,
    DateTime? timestamp,
    String? reportedBy,
    String? proofImagePath,
    int? pointsDeducted,
    String? reporterId,
  }) {
    return DisciplineCase(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      reportedBy: reportedBy ?? this.reportedBy,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      pointsDeducted: pointsDeducted ?? this.pointsDeducted,
      reporterId: reporterId ?? this.reporterId,
    );
  }

  factory DisciplineCase.fromFirestore(Map<String, dynamic> data, String id) {
    return DisciplineCase(
      id: id,
      studentId: data['studentId'] ?? '',
      category: data['category'] ?? '',
      subCategory: data['subCategory'] ?? 'General',
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      severity: data['severity'] ?? 'Normal',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      proofImagePath: data['proofImagePath'],
      reportedBy: data['reportedBy'] ?? 'System',
      pointsDeducted: data['pointsDeducted'],
      reporterId: data['reporterId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'category': category,
      'subCategory': subCategory,
      'subject': subject,
      'description': description,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'proofImagePath': proofImagePath,
      'reportedBy': reportedBy,
      if (pointsDeducted != null) 'pointsDeducted': pointsDeducted,
      if (reporterId != null) 'reporterId': reporterId,
    };
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    category,
    subCategory,
    subject,
    description,
    severity,
    timestamp,
    proofImagePath,
    reportedBy,
    reporterId,
  ];
}
