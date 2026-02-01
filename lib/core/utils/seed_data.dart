import 'package:cloud_firestore/cloud_firestore.dart';

class SeedData {
  static Future<void> seedDisputeTypes() async {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('dispute_types');

    // Check if empty
    final snapshot = await collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      print('✅ Dispute types already seeded.');
      return;
    }

    final types = [
      {
        'name': 'Late Entry',
        'category': 'Administrative Services',
        'severity': 'Normal',
      },
      {
        'name': 'Uniform Issue',
        'category': 'Academic Affairs',
        'severity': 'Normal',
      },
      {
        'name': 'ID Card Missing',
        'category': 'Academic Affairs',
        'severity': 'Normal',
      },
      {'name': 'Misconduct', 'category': 'Behavioral', 'severity': 'High'},
      {'name': 'Property Damage', 'category': 'Behavioral', 'severity': 'High'},
    ];

    final batch = firestore.batch();
    for (var type in types) {
      final doc = collection.doc(); // Auto-ID
      batch.set(doc, type);
    }

    await batch.commit();
    print('✅ Seeded ${types.length} dispute types to Firestore.');
  }
}
