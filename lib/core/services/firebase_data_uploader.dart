import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utility class to upload initial data to Firebase
/// Run this once to populate Firestore with test/initial data
class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Single Root Collection 'collegesynx'
  // Structure:
  // users: collegesynx/data/users/{uid}
  // events: collegesynx/data/events/{id}
  // students: collegesynx/database/hierarchy/... (keeping logic similar but nested)

  Future<void> uploadAllData() async {
    print('🚀 Starting Firebase data upload into "collegesynx" collection...');

    try {
      await createFacultyAccount();
      await createSecurityAccount();
      await createHodAccount();
      await createSecurityAdminAccount();
      await uploadEvents();
      // await uploadStudents(); // Optional, uncomment if needed

      print('✅ All data uploaded successfully!');
    } catch (e) {
      print('❌ Error uploading data: $e');
    }
  }

  /// Create faculty test account
  Future<void> createFacultyAccount() async {
    await _createAccount(
      email: 'faculty@collegesynx.edu.in',
      password: 'password123',
      role: 'faculty',
      name: 'Dr. Faculty User',
      collegeId: 'faculty',
      additionalData: {},
    );
  }

  /// Create security test account
  Future<void> createSecurityAccount() async {
    await _createAccount(
      email: 'security@collegesynx.edu.in',
      password: 'password123',
      role: 'security',
      name: 'Security Guard',
      collegeId: 'security',
      additionalData: {},
    );
  }

  /// Create HOD test account
  Future<void> createHodAccount() async {
    await _createAccount(
      email: 'hod.csm@collegesynx.edu.in',
      password: 'password123',
      role: 'hod',
      name: 'Dr. HOD CSM',
      collegeId: 'hod',
      additionalData: {'department': 'CSM'},
    );
  }

  /// Create Security Admin test account
  Future<void> createSecurityAdminAccount() async {
    await _createAccount(
      email: 'security.chief@collegesynx.edu.in',
      password: 'password123',
      role: 'securityAdmin',
      name: 'Chief Security Officer',
      collegeId: 'securityadmin',
      additionalData: {},
    );
  }

  /// Helper to create Auth User + Firestore Doc
  Future<void> _createAccount({
    required String email,
    required String password,
    required String role,
    required String name,
    required String collegeId,
    required Map<String, dynamic> additionalData,
  }) async {
    print('📝 Creating $role account ($email)...');
    try {
      // 1. Create in Firebase Auth
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          print(
            '⚠️  Account $email already exists in Auth. Updating Firestore...',
          );
          // Proceed to update Firestore even if Auth exists, to ensure data consistency
          // We need the UID. Since we can't get it from failure, we'll try login or assuming existing UID/structure?
          // Actually, we can't get UID easily if we don't sign in.
          // BUT, we can try to sign in to get the UID.
          try {
            userCredential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (loginError) {
            print(
              '❌ Could not login to existing account to update Firestore: $loginError',
            );
            return;
          }
        } else {
          rethrow;
        }
      }

      final uid = userCredential.user!.uid;

      // 2. Create/Update in Firestore under 'collegesynx/data/users/{uid}'
      // We use a subcollection 'users' inside a document 'data' of the root collection 'collegesynx'
      // Path: collegesynx/data/users/{uid} implies:
      // Collection: collegesynx
      // Doc: data
      // SubCollection: users
      // Doc: {uid}

      final docRef = _firestore
          .collection('collegesynx')
          .doc('data')
          .collection('users')
          .doc(uid);

      await docRef.set({
        'id': uid,
        'name': name,
        'email': email,
        'role': role,
        'collegeId': collegeId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        ...additionalData,
      }, SetOptions(merge: true));

      print('✅ Account $role synced to Firestore path: ${docRef.path}');
    } catch (e) {
      print('❌ Error creating/syncing $role: $e');
    }
  }

  /// Upload sample events
  Future<void> uploadEvents() async {
    print('📝 Uploading events...');

    final events = [
      {
        'id': 'event001',
        'title': 'Annual Day 2026',
        'description': 'The grand annual celebration of CollegeSynx.',
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
    ];

    final batch = _firestore.batch();

    for (var event in events) {
      // Path: collegesynx/data/events/{id}
      final docRef = _firestore
          .collection('collegesynx')
          .doc('data')
          .collection('events')
          .doc(event['id'] as String);
      batch.set(docRef, event);
    }

    await batch.commit();
    print('✅ ${events.length} events uploaded to collegesynx/data/events');
  }
}
