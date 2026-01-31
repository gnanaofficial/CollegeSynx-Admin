import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../entities/student.dart';

abstract class StudentRepository {
  /// Get student by exact roll number (searches across all students)
  Future<Either<Exception, Student?>> getStudentByRollNo(String rollNo);

  /// Get student by barcode
  Future<Either<Exception, Student?>> getStudentByBarcode(String barcode);

  /// Get list of students for a specific branch
  Future<Either<Exception, List<Student>>> getStudentsByBranch({
    required String dept,
    required String batch,
    required String branch,
  });

  /// Download student photo from R2 (returns bytes)
  Future<Either<Exception, Uint8List>> downloadStudentPhoto(String photoUrl);

  /// Update student embedding in Firestore (legacy - single embedding)
  Future<Either<Exception, void>> updateStudentEmbedding(
    String rollNo,
    List<double> embedding,
  );

  /// Update student embeddings with multi-angle data
  Future<Either<Exception, void>> updateStudentEmbeddings(
    String rollNo,
    List<List<double>> embeddings,
    Map<String, dynamic> metadata,
  );
}
