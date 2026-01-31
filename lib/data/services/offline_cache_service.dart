import 'dart:math' as math;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/student_embedding.dart';
import 'package:dartz/dartz.dart';

/// Service for offline caching of student embeddings
class OfflineCacheService {
  static const String _boxName = 'student_embeddings';
  Box<StudentEmbedding>? _box;

  /// Initialize Hive and open box
  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(StudentEmbeddingAdapter());
    _box = await Hive.openBox<StudentEmbedding>(_boxName);
  }

  /// Cache a single student embedding
  Future<void> cacheEmbedding(StudentEmbedding embedding) async {
    await _box?.put(embedding.rollNo, embedding);
  }

  /// Cache multiple embeddings
  Future<void> cacheEmbeddings(List<StudentEmbedding> embeddings) async {
    final Map<String, StudentEmbedding> map = {
      for (var e in embeddings) e.rollNo: e,
    };
    await _box?.putAll(map);
  }

  /// Get embedding by roll number
  StudentEmbedding? getEmbedding(String rollNo) {
    return _box?.get(rollNo);
  }

  /// Get all embeddings for a department
  List<StudentEmbedding> getEmbeddingsByDept(String dept) {
    return _box?.values.where((e) => e.dept == dept).toList() ?? [];
  }

  /// Get all embeddings for a batch
  List<StudentEmbedding> getEmbeddingsByBatch(String dept, String batch) {
    return _box?.values
            .where((e) => e.dept == dept && e.batch == batch)
            .toList() ??
        [];
  }

  /// Get all embeddings for a branch
  List<StudentEmbedding> getEmbeddingsByBranch(
    String dept,
    String batch,
    String branch,
  ) {
    return _box?.values
            .where(
              (e) => e.dept == dept && e.batch == batch && e.branch == branch,
            )
            .toList() ??
        [];
  }

  /// Get all cached embeddings
  List<StudentEmbedding> getAllEmbeddings() {
    return _box?.values.toList() ?? [];
  }

  /// Check if embedding exists
  bool hasEmbedding(String rollNo) {
    return _box?.containsKey(rollNo) ?? false;
  }

  /// Delete embedding
  Future<void> deleteEmbedding(String rollNo) async {
    await _box?.delete(rollNo);
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _box?.clear();
  }

  /// Get cache size
  int getCacheSize() {
    return _box?.length ?? 0;
  }

  /// Get last updated time for a student
  DateTime? getLastUpdated(String rollNo) {
    return _box?.get(rollNo)?.lastUpdated;
  }

  /// Find closest match using cosine similarity
  /// Returns (rollNo, similarity score)
  Future<Either<Exception, (String, double)?>> findClosestMatch(
    List<double> queryEmbedding, {
    double threshold = 0.75,
    String? dept,
    String? batch,
    String? branch,
  }) async {
    try {
      List<StudentEmbedding> candidates;

      // Filter by dept/batch/branch if provided
      if (branch != null && batch != null && dept != null) {
        candidates = getEmbeddingsByBranch(dept, batch, branch);
      } else if (batch != null && dept != null) {
        candidates = getEmbeddingsByBatch(dept, batch);
      } else if (dept != null) {
        candidates = getEmbeddingsByDept(dept);
      } else {
        candidates = getAllEmbeddings();
      }

      if (candidates.isEmpty) {
        return const Right(null);
      }

      double bestScore = 0.0;
      String? bestMatch;

      for (final candidate in candidates) {
        // Compare with all 3 embeddings, take the best score
        final scores = [
          _cosineSimilarity(queryEmbedding, candidate.embedding1),
          _cosineSimilarity(queryEmbedding, candidate.embedding2),
          _cosineSimilarity(queryEmbedding, candidate.embedding3),
        ];

        final maxScore = scores.reduce((a, b) => a > b ? a : b);

        if (maxScore > bestScore) {
          bestScore = maxScore;
          bestMatch = candidate.rollNo;
        }
      }

      if (bestScore >= threshold && bestMatch != null) {
        return Right((bestMatch, bestScore));
      }

      return const Right(null);
    } catch (e) {
      return Left(Exception('Error finding match: $e'));
    }
  }

  /// Calculate cosine similarity between two embeddings
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Close the box
  Future<void> close() async {
    await _box?.close();
  }
}
