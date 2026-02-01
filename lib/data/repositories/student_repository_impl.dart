import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/student.dart';
import '../../domain/repositories/student_repository.dart';

class StudentRepositoryImpl implements StudentRepository {
  final FirebaseFirestore _firestore;

  // TODO: Add R2 API endpoint configuration
  static const String r2ApiUrl = 'https://your-api.com/api/r2/image';

  StudentRepositoryImpl(this._firestore);

  @override
  Future<Either<Exception, Student?>> getStudentByRollNo(String rollNo) async {
    try {
      // Use collectionGroup to search across all nested 'students' collections
      // FIXED: Collection name is 'students' (lowercase) based on user screenshot
      final snapshot = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: rollNo)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Right(null);
      }

      return Right(Student.fromFirestore(snapshot.docs.first));
    } catch (e) {
      return Left(Exception('Failed to fetch student: $e'));
    }
  }

  @override
  Future<Either<Exception, Student?>> getStudentByBarcode(
    String barcode,
  ) async {
    try {
      // FIXED: Collection name is 'students' (lowercase)
      final snapshot = await _firestore
          .collectionGroup('students')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return const Right(null);

      return Right(Student.fromFirestore(snapshot.docs.first));
    } catch (e) {
      return Left(Exception('Failed to fetch student by barcode: $e'));
    }
  }

  @override
  Future<Either<Exception, List<Student>>> getStudentsByBranch({
    required String dept,
    required String batch,
    required String branch,
  }) async {
    try {
      // Updated path based on screenshot:
      // /departments/B.Tech/batches/2026-2030/branches/CSM/students
      // Note: 'dept' param likely maps to 'B.Tech' (program) or similar.
      // We will assume 'departments' is the root collection.

      final snapshot = await _firestore
          .collection('departments')
          .doc(dept) // e.g., 'B.Tech'
          .collection('batches')
          .doc(batch) // e.g., '2026-2030'
          .collection('branches')
          .doc(branch) // e.g., 'CSM'
          .collection('students')
          .orderBy('rollNo')
          .get();

      final students = snapshot.docs
          .map((doc) => Student.fromFirestore(doc))
          .toList();

      return Right(students);
    } catch (e) {
      return Left(Exception('Failed to fetch students list: $e'));
    }
  }

  @override
  Future<Either<Exception, Uint8List>> downloadStudentPhoto(
    String photoUrl,
  ) async {
    try {
      if (photoUrl.isEmpty) {
        return Left(Exception('Photo URL is empty'));
      }

      // If it's a full URL, use it directly
      final uri = photoUrl.startsWith('http')
          ? Uri.parse(photoUrl)
          : Uri.parse('$r2ApiUrl?key=${Uri.encodeComponent(photoUrl)}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return Right(response.bodyBytes);
      } else {
        return Left(
          Exception('Failed to download photo: ${response.statusCode}'),
        );
      }
    } catch (e) {
      return Left(Exception('Error downloading photo: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateStudentEmbedding(
    String rollNo,
    List<double> embedding,
  ) async {
    try {
      // 1. Find the student document
      // FIXED: Collection name is 'students' (lowercase)
      final snapshot = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: rollNo)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return Left(Exception('Student not found for embedding update'));
      }

      final docRef = snapshot.docs.first.reference;

      // 2. Update the document
      await docRef.update({
        'embedding': embedding,
        'embeddings': FieldValue.delete(), // Legacy array
        'embedding1': FieldValue.delete(), // Legacy multi
        'embedding2': FieldValue.delete(), // Legacy multi
        'embedding3': FieldValue.delete(), // Legacy multi
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return const Right(null);
    } catch (e) {
      return Left(Exception('Failed to update embedding: $e'));
    }
  }

  @override
  Future<void> updateStudentCredits(String studentId, int newCredits) async {
    try {
      // Since students are in subcollections, we need to find the document first
      final querySnapshot = await _firestore
          .collectionGroup('students')
          .where(FieldPath.documentId, isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Student not found: $studentId');
      }

      final docRef = querySnapshot.docs.first.reference;

      await docRef.update({
        'credits': newCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update student credits: $e');
    }
  }

  @override
  Future<Either<Exception, void>> updateStudentEmbeddings(
    String rollNo,
    List<List<double>> embeddings,
    Map<String, dynamic> metadata,
  ) async {
    try {
      // 1. Find the student document
      // FIXED: Collection name is 'students' (lowercase)
      final snapshot = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: rollNo)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return Left(Exception('Student not found for embeddings update'));
      }

      final docRef = snapshot.docs.first.reference;

      // 2. Update Firestore
      // We write BOTH the flattened fields (for existing compatibility) AND the array (for future proofing)
      await docRef.update({
        'embeddings': embeddings, // Standard array format
        'embedding1': embeddings.isNotEmpty ? embeddings[0] : null,
        'embedding2': embeddings.length > 1 ? embeddings[1] : null,
        'embedding3': embeddings.length > 2 ? embeddings[2] : null,
        'embeddingMetadata': {
          ...metadata,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });

      return const Right(null);
    } catch (e) {
      return Left(Exception('Failed to update embeddings: $e'));
    }
  }
}
