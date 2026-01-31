import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/role_config.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _prefs;

  static const String _userKey = 'auth_user_id';
  static const String _roleKey = 'auth_user_role';
  static const String _nameKey = 'auth_user_name';
  static const String _emailKey = 'auth_user_email';

  UserEntity? _currentUser;

  AuthRepositoryImpl(this._prefs);

  @override
  Future<Either<Exception, UserEntity>> login({
    required String collegeId,
    required String password,
    required UserRole role,
  }) async {
    try {
      // Convert collegeId to email format if needed
      String email = collegeId.contains('@')
          ? collegeId
          : '$collegeId@svce.edu.in';

      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        return Left(Exception('Authentication failed'));
      }

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        // Create user document if it doesn't exist (first time login)
        final userData = {
          'id': uid,
          'name': userCredential.user?.displayName ?? 'User',
          'email': email,
          'role': role.name,
          'collegeId': collegeId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(uid).set(userData);

        final user = UserEntity(
          id: uid,
          name: userData['name'] as String,
          email: email,
          role: role,
        );

        await _saveUserToPrefs(user);
        _currentUser = user;
        return Right(user);
      }

      // Parse existing user data
      final data = userDoc.data()!;
      final userRole = _parseRole(data['role'] as String?);

      // Verify role matches
      if (userRole != role) {
        await _auth.signOut();
        return Left(
          Exception(
            'Role mismatch: This account is registered as ${userRole.name}',
          ),
        );
      }

      // Update last login
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      final user = UserEntity(
        id: uid,
        name: data['name'] as String? ?? 'User',
        email: email,
        role: userRole,
      );

      await _saveUserToPrefs(user);
      _currentUser = user;
      return Right(user);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message}';
      }
      return Left(Exception(errorMessage));
    } catch (e) {
      return Left(Exception('Login failed: ${e.toString()}'));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      await _prefs.remove(_userKey);
      await _prefs.remove(_roleKey);
      await _prefs.remove(_nameKey);
      await _prefs.remove(_emailKey);
    } catch (e) {
      // Even if sign out fails, clear local data
      _currentUser = null;
      await _prefs.clear();
    }
  }

  @override
  Future<Either<Exception, UserEntity?>> getCurrentUser() async {
    try {
      // Check memory cache
      if (_currentUser != null) return Right(_currentUser);

      // Check Firebase Auth
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        // Try to restore from SharedPreferences (offline support)
        return Right(await _getUserFromPrefs());
      }

      // Fetch from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        return Right(null);
      }

      final data = userDoc.data()!;
      final user = UserEntity(
        id: firebaseUser.uid,
        name: data['name'] as String? ?? 'User',
        email: data['email'] as String? ?? firebaseUser.email ?? '',
        role: _parseRole(data['role'] as String?),
      );

      await _saveUserToPrefs(user);
      _currentUser = user;
      return Right(user);
    } catch (e) {
      // Fallback to cached data in SharedPreferences
      return Right(await _getUserFromPrefs());
    }
  }

  Future<void> _saveUserToPrefs(UserEntity user) async {
    await _prefs.setString(_userKey, user.id);
    await _prefs.setString(_roleKey, user.role.name);
    await _prefs.setString(_nameKey, user.name);
    await _prefs.setString(_emailKey, user.email);
  }

  Future<UserEntity?> _getUserFromPrefs() async {
    final userId = _prefs.getString(_userKey);
    final roleName = _prefs.getString(_roleKey);
    final name = _prefs.getString(_nameKey);
    final email = _prefs.getString(_emailKey);

    if (userId != null && roleName != null && name != null && email != null) {
      return UserEntity(
        id: userId,
        name: name,
        email: email,
        role: _parseRole(roleName),
      );
    }
    return null;
  }

  UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'security':
        return UserRole.security;
      case 'admin':
        return UserRole.admin;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.student; // Default fallback
    }
  }
}
