import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utility class to upload initial data to Firebase
/// Run this once to populate Firestore with test/initial data
class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload all initial data to Firebase
  Future<void> uploadAllData() async {
    print('🚀 Starting Firebase data upload...');

    try {
      await createFacultyAccount();
      await createSecurityAccount();
      await uploadEvents();

      print('✅ All data uploaded successfully!');
    } catch (e) {
      print('❌ Error uploading data: $e');
    }
  }

  /// Create faculty test account
  Future<void> createFacultyAccount() async {
    print('📝 Creating faculty account...');

    try {
      // Create auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: 'faculty@svce.edu.in',
        password: 'password123',
      );

      final uid = userCredential.user!.uid;

      // Create Firestore document
      await _firestore.collection('users').doc(uid).set({
        'id': uid,
        'name': 'Dr. Faculty Test',
        'email': 'faculty@svce.edu.in',
        'role': 'faculty',
        'collegeId': 'faculty',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('✅ Faculty account created: $uid');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('⚠️  Faculty account already exists');
      } else {
        print('❌ Error creating faculty: ${e.message}');
      }
    }
  }

  /// Create security test account
  Future<void> createSecurityAccount() async {
    print('📝 Creating security account...');

    try {
      // Create auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: 'security@svce.edu.in',
        password: 'password123',
      );

      final uid = userCredential.user!.uid;

      // Create Firestore document
      await _firestore.collection('users').doc(uid).set({
        'id': uid,
        'name': 'Security Officer',
        'email': 'security@svce.edu.in',
        'role': 'security',
        'collegeId': 'security',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('✅ Security account created: $uid');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('⚠️  Security account already exists');
      } else {
        print('❌ Error creating security: ${e.message}');
      }
    }
  }

  /// Upload sample events
  Future<void> uploadEvents() async {
    print('📝 Uploading events...');

    final events = [
      {
        'id': 'event001',
        'title': 'Annual Day 2026',
        'description': 'The grand annual celebration of SVCE.',
        'date': DateTime.now().add(const Duration(days: 5)),
        'location': 'Main Auditorium',
        'requiresLiveVerification': true,
        'totalRegistrations': 1200,
        'checkedInCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'event002',
        'title': 'Tech Symposium',
        'description': 'Technical paper presentations and workshops.',
        'date': DateTime.now().add(const Duration(days: 12)),
        'location': 'CSE Block',
        'requiresLiveVerification': false,
        'totalRegistrations': 300,
        'checkedInCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'event003',
        'title': 'Alumni Meet',
        'description': 'Networking event for alumni.',
        'date': DateTime.now().add(const Duration(days: 20)),
        'location': 'College Grounds',
        'requiresLiveVerification': true,
        'totalRegistrations': 500,
        'checkedInCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();

    for (var event in events) {
      final docRef = _firestore.collection('events').doc(event['id'] as String);
      batch.set(docRef, event);
    }

    await batch.commit();
    print('✅ ${events.length} events uploaded');
  }

  /// Upload sample students (optional - add your own student data)
  Future<void> uploadStudents() async {
    print('📝 Uploading students...');

    final students = [
      {
        'id': '24BFA33L12',
        'name': 'Kalapati Ganana Sekhar',
        'regNo': '24BFA33L12',
        'program': 'B.Tech',
        'batch': '2024-2027',
        'department': 'CSM',
        'section': 'E',
        'college': 'S.V. College of Engineering',
        'photoUrl': 'assets/images/24BFA33L12.jpeg',
        'barcodeValue': '24BFA33L12',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': '24BFA33L04',
        'name': 'Anangi Vignesh Kumar',
        'regNo': '24BFA33L04',
        'program': 'B.Tech',
        'batch': '2024-2027',
        'department': 'CSM',
        'section': 'E',
        'college': 'S.V. College of Engineering',
        'photoUrl': 'assets/images/student_placeholder.png',
        'barcodeValue': '24BFA33L04',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    // Upload to hierarchical structure: Database/Students/{program}/{batch}/{department}/{id}
    for (var student in students) {
      await _firestore
          .collection('Database')
          .doc('Students')
          .collection(student['program'] as String)
          .doc(student['batch'] as String)
          .collection(student['department'] as String)
          .doc(student['id'] as String)
          .set(student);
    }

    print('✅ ${students.length} students uploaded');
  }
}
