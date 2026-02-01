import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/discipline_case.dart';
import '../../domain/repositories/discipline_repository.dart';

class DisciplineRepositoryImpl implements DisciplineRepository {
  final FirebaseFirestore _firestore;

  DisciplineRepositoryImpl(this._firestore);

  @override
  Future<List<DisciplineCase>> getHistory(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('discipline_cases')
          .where('studentId', isEqualTo: studentId)
          .get();

      final cases = snapshot.docs
          .map((doc) => DisciplineCase.fromFirestore(doc.data(), doc.id))
          .toList();

      // Sort client-side to avoid needing a Firestore composite index immediately
      cases.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return cases;
    } catch (e) {
      throw Exception('Failed to fetch discipline history: $e');
    }
  }

  @override
  Future<void> raiseCase(DisciplineCase disciplineCase) async {
    try {
      // 1. Find Student Reference (Robust Lookup)
      final studentQuery = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: disciplineCase.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) {
        throw Exception(
          'Student not found matching Roll No: ${disciplineCase.studentId}',
        );
      }

      final studentRef = studentQuery.docs.first.reference;
      print('DEBUG: Found student ref: ${studentRef.path}');

      await _firestore.runTransaction((transaction) async {
        // 2. Read current credits within transaction
        final studentSnapshot = await transaction.get(studentRef);

        if (!studentSnapshot.exists) {
          throw Exception("Student document disappeared during transaction!");
        }

        final data = studentSnapshot.data();
        final currentCredits = (data != null && data.containsKey('credits'))
            ? (data['credits'] as num).toInt()
            : 100; // Default to 100 if field missing

        // 3. Calculate Deduction
        int deduction = 0;
        // Default rule: If not High severity, deduct 5.
        // User said: "attendance or other credits are marked as a late entry, it should be decreased."
        // CreateCaseFlow passes 'Normal' or 'High'.
        // Mark Late passes 'Normal'.
        if (disciplineCase.severity != 'High') {
          deduction = 5;
        }

        // Allow explicit override
        if (disciplineCase.pointsDeducted != null) {
          deduction = disciplineCase.pointsDeducted!;
        }

        final newCredits = currentCredits - deduction;
        print('DEBUG: New Credits: $newCredits');

        // 4. Update Case Object
        final caseToSave = disciplineCase.copyWith(pointsDeducted: deduction);

        // 5. Writes
        final newCaseRef = _firestore.collection('discipline_cases').doc();
        transaction.set(newCaseRef, caseToSave.toMap());

        // CRITICAL: Update student credits
        transaction.update(studentRef, {
          'credits': newCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      print('DEBUG: Transaction committed successfully.');
    } catch (e) {
      print('DEBUG: Transaction Failed: $e');
      throw Exception('Failed to raise case: $e');
    }
  }

  @override
  Future<List<String>> getDisputeTypes() async {
    try {
      final snapshot = await _firestore.collection('dispute_types').get();
      if (snapshot.docs.isEmpty) return [];

      // Assuming structure { 'name': 'Late Entry' }
      return snapshot.docs.map((d) => d.data()['name'] as String).toList();
    } catch (e) {
      // Fallback if needed, or return empty
      return [];
    }
  }

  @override
  Future<void> deleteCase(String caseId, String studentId) async {
    try {
      // 1. Find Student Reference
      final studentQuery = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) {
        throw Exception('Student not found matching Roll No: $studentId');
      }
      final studentRef = studentQuery.docs.first.reference;
      final caseRef = _firestore.collection('discipline_cases').doc(caseId);

      await _firestore.runTransaction((transaction) async {
        // 2. Read Docs
        final caseSnapshot = await transaction.get(caseRef);
        final studentSnapshot = await transaction.get(studentRef);

        if (!caseSnapshot.exists) {
          throw Exception('Case not found');
        }

        // 3. Determine Reversal Amount
        final caseData = caseSnapshot.data()!;
        final pointsDeducted =
            (caseData['pointsDeducted'] as num?)?.toInt() ?? 0;

        // 4. Update Student Credits
        if (studentSnapshot.exists && pointsDeducted > 0) {
          final studentData = studentSnapshot.data();
          final currentCredits =
              (studentData != null && studentData.containsKey('credits'))
              ? (studentData['credits'] as num).toInt()
              : 100;

          final newCredits = currentCredits + pointsDeducted;

          transaction.update(studentRef, {
            'credits': newCredits > 100
                ? 100
                : newCredits, // Cap at 100? Assuming max is 100.
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 5. Delete Case
        transaction.delete(caseRef);
      });
    } catch (e) {
      throw Exception('Failed to delete case: $e');
    }
  }

  @override
  Future<void> resetCredits(String studentId) async {
    try {
      final studentQuery = await _firestore
          .collectionGroup('students')
          .where('rollNo', isEqualTo: studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) {
        throw Exception('Student not found matching Roll No: $studentId');
      }

      await studentQuery.docs.first.reference.update({
        'credits': 100,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reset credits: $e');
    }
  }

  @override
  Future<List<DisciplineCase>> getReportedCases(String reporterId) async {
    try {
      final snapshot = await _firestore
          .collection('discipline_cases')
          .where('reporterId', isEqualTo: reporterId)
          .get();

      final cases = snapshot.docs
          .map((doc) => DisciplineCase.fromFirestore(doc.data(), doc.id))
          .toList();

      cases.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return cases;
    } catch (e) {
      throw Exception('Failed to fetch reported cases: $e');
    }
  }

  @override
  Future<List<DisciplineCase>> getRecentCases({int limit = 20}) async {
    try {
      final snapshot = await _firestore.collection('discipline_cases').get();

      final cases = snapshot.docs
          .map((doc) => DisciplineCase.fromFirestore(doc.data(), doc.id))
          .toList();

      cases.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return cases.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent cases: $e');
    }
  }
}
