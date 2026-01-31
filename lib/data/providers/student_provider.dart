import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/student_repository.dart';
import '../repositories/student_repository_impl.dart';

// Firebase Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Student Repository provider (SIMPLE - Firestore only)
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return StudentRepositoryImpl(firestore);
});
