import 'package:hive/hive.dart';

part 'student_embedding.g.dart';

/// Hive model for offline caching of student embeddings
@HiveType(typeId: 0)
class StudentEmbedding extends HiveObject {
  @HiveField(0)
  final String rollNo;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String dept;

  @HiveField(3)
  final String batch;

  @HiveField(4)
  final String branch;

  @HiveField(5)
  final List<double> embedding1;

  @HiveField(6)
  final List<double> embedding2;

  @HiveField(7)
  final List<double> embedding3;

  @HiveField(8)
  final DateTime lastUpdated;

  StudentEmbedding({
    required this.rollNo,
    required this.name,
    required this.dept,
    required this.batch,
    required this.branch,
    required this.embedding1,
    required this.embedding2,
    required this.embedding3,
    required this.lastUpdated,
  });

  /// Get all embeddings as a list
  List<List<double>> get embeddings => [embedding1, embedding2, embedding3];

  /// Create from embeddings list
  factory StudentEmbedding.fromEmbeddings({
    required String rollNo,
    required String name,
    required String dept,
    required String batch,
    required String branch,
    required List<List<double>> embeddings,
  }) {
    return StudentEmbedding(
      rollNo: rollNo,
      name: name,
      dept: dept,
      batch: batch,
      branch: branch,
      embedding1: embeddings.length > 0 ? embeddings[0] : List.filled(128, 0.0),
      embedding2: embeddings.length > 1 ? embeddings[1] : List.filled(128, 0.0),
      embedding3: embeddings.length > 2 ? embeddings[2] : List.filled(128, 0.0),
      lastUpdated: DateTime.now(),
    );
  }
}
