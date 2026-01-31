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
  });

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
  ];
}
