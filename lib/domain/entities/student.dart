import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Student entity model matching Firebase Firestore schema
class Student extends Equatable {
  final String rollNo;
  final String name;
  final String email;
  final String course; // Department (B.Tech, MBA, MCA)
  final String branch; // CSM, CSE, etc.
  final String year; // Batch (2025-2029)
  final String section;
  final String
  photoUrl; // R2 path: Departments/{dept}/{batch}/{branch}/{rollNo}.jpg

  // Optional fields from schema
  final String? startYear;
  final String? endYear;
  final String? fatherName;
  final String? fPhone;
  final String? address;
  final String? pin;
  final String? bloodGroup;
  final String? dob;
  final String? barcode;
  final String? adharNo;
  final String? updatedAt;

  // Metadata
  final String? firestorePath; // Full Firestore document path for reference

  // Face Recognition Data
  // Legacy: single embedding (deprecated, use embeddings instead)
  final List<double>? embedding;

  // Multi-angle embeddings: [front, leftProfile, rightProfile]
  final List<List<double>>? embeddings;

  // Metadata for embeddings (timestamps, quality scores, pose angles)
  final Map<String, dynamic>? embeddingMetadata;

  // Gamification
  final int credits;

  const Student({
    required this.rollNo,
    required this.name,
    required this.email,
    required this.course,
    required this.branch,
    required this.year,
    required this.section,
    required this.photoUrl,
    this.credits = 100, // Default credits
    this.firestorePath,
    this.embedding,
    this.embeddings,
    this.embeddingMetadata,
    this.startYear,
    this.endYear,
    this.fatherName,
    this.fPhone,
    this.address,
    this.pin,
    this.bloodGroup,
    this.dob,
    this.barcode,
    this.adharNo,
    this.updatedAt,
  });

  /// Create Student from Firestore DocumentSnapshot
  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String processPhotoUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      const baseUrl = 'https://pub-3d6d4bb627f0412ea00d3ccda8b45b29.r2.dev/';
      return '$baseUrl${url.startsWith('/') ? url.substring(1) : url}';
    }

    // Logic to handle multiple embedding storage formats
    List<List<double>>? parsedEmbeddings;

    if (data['embeddings'] != null) {
      // 1. Standard Array format
      parsedEmbeddings = (data['embeddings'] as List)
          .map((e) => List<double>.from(e))
          .toList();
    } else {
      // 2. Flattened Fields format (embedding1, embedding2, ...)
      // This fixes the issue where app ignores multi-angle data
      final List<List<double>> recovered = [];
      if (data['embedding1'] != null) {
        recovered.add(List<double>.from(data['embedding1']));
      }
      if (data['embedding2'] != null) {
        recovered.add(List<double>.from(data['embedding2']));
      }
      if (data['embedding3'] != null) {
        recovered.add(List<double>.from(data['embedding3']));
      }

      if (recovered.isNotEmpty) {
        parsedEmbeddings = recovered;
      }
    }

    return Student(
      rollNo: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      course: data['course']?.toString() ?? '',
      branch: data['branch']?.toString() ?? '',
      year: data['year']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
      photoUrl: processPhotoUrl(data['photoUrl']?.toString()),
      firestorePath: doc.reference.path,
      startYear: data['startYear']?.toString(),
      endYear: data['endYear']?.toString(),
      fatherName: data['fatherName']?.toString(),
      fPhone: data['fPhone']?.toString(),
      address: data['address']?.toString(),
      pin: data['pin']?.toString(),
      bloodGroup: data['bloodGroup']?.toString(),
      dob: data['dob']?.toString(), // Handle Excel serial or string
      barcode: data['barcode']?.toString(),
      adharNo: data['adharNo']?.toString(),
      updatedAt: data['updatedAt']?.toString(),
      credits: (data['credits'] is num)
          ? (data['credits'] as num).toInt()
          : 100,
      // Legacy single embedding support
      embedding: data['embedding'] != null
          ? List<double>.from(data['embedding'])
          : null,
      // Multi-angle embeddings (Unified)
      embeddings: parsedEmbeddings,
      embeddingMetadata: data['embeddingMetadata'] != null
          ? Map<String, dynamic>.from(data['embeddingMetadata'])
          : null,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'rollNo': rollNo,
      'name': name,
      'email': email,
      'course': course,
      'branch': branch,
      'year': year,
      'section': section,
      'photoUrl': photoUrl,
      'credits': credits,
      if (startYear != null) 'startYear': startYear,
      if (endYear != null) 'endYear': endYear,
      if (fatherName != null) 'fatherName': fatherName,
      if (fPhone != null) 'fPhone': fPhone,
      if (address != null) 'address': address,
      if (pin != null) 'pin': pin,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (dob != null) 'dob': dob,
      if (barcode != null) 'barcode': barcode,
      if (adharNo != null) 'adharNo': adharNo,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (embedding != null) 'embedding': embedding,
      if (embeddings != null) 'embeddings': embeddings,
      if (embeddingMetadata != null) 'embeddingMetadata': embeddingMetadata,
    };
  }

  /// Get display name with roll number
  String get displayName => '$name ($rollNo)';

  /// Get academic info string
  String get academicInfo => '$course - $branch - $section';

  @override
  List<Object?> get props => [
    rollNo,
    name,
    email,
    course,
    branch,
    year,
    section,
    photoUrl,
    startYear,
    endYear,
    fatherName,
    fPhone,
    address,
    pin,
    bloodGroup,
    dob,
    barcode,
    adharNo,
    updatedAt,
    firestorePath,
    embedding,
    embeddings,
    embeddingMetadata,
    credits,
  ];
}
