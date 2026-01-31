import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for storing and retrieving face embeddings from Cloud Storage
/// Structure: embeddings/{dept}/{batch}/{branch}/{rollNo}.bin
class CloudStorageService {
  final FirebaseStorage _storage;

  CloudStorageService(this._storage);

  /// Upload embeddings to Cloud Storage
  /// Stores as binary file: 3 embeddings × 128 floats = 384 floats
  Future<String> uploadEmbeddings({
    required String rollNo,
    required String dept,
    required String batch,
    required String branch,
    required List<List<double>> embeddings,
  }) async {
    try {
      // Convert embeddings to binary
      final bytes = _embeddingsToBytes(embeddings);

      // Create path: embeddings/CSE/2021/A/21CS001.bin
      final path = 'embeddings/$dept/$batch/$branch/$rollNo.bin';
      final ref = _storage.ref().child(path);

      // Upload
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {
            'rollNo': rollNo,
            'dept': dept,
            'batch': batch,
            'branch': branch,
            'uploadDate': DateTime.now().toIso8601String(),
            'embeddingCount': embeddings.length.toString(),
          },
        ),
      );

      return path;
    } catch (e) {
      throw Exception('Failed to upload embeddings: $e');
    }
  }

  /// Download embeddings from Cloud Storage
  Future<List<List<double>>> downloadEmbeddings({
    required String rollNo,
    required String dept,
    required String batch,
    required String branch,
  }) async {
    try {
      final path = 'embeddings/$dept/$batch/$branch/$rollNo.bin';
      final ref = _storage.ref().child(path);

      final bytes = await ref.getData();
      if (bytes == null) {
        throw Exception('Embeddings not found');
      }

      return _bytesToEmbeddings(bytes);
    } catch (e) {
      throw Exception('Failed to download embeddings: $e');
    }
  }

  /// Download all embeddings for a department (for offline caching)
  Future<Map<String, List<List<double>>>> downloadDepartmentEmbeddings({
    required String dept,
    required String batch,
    required String branch,
  }) async {
    try {
      final path = 'embeddings/$dept/$batch/$branch/';
      final ref = _storage.ref().child(path);

      final result = await ref.listAll();
      final Map<String, List<List<double>>> embeddings = {};

      for (final item in result.items) {
        final rollNo = item.name.replaceAll('.bin', '');
        final bytes = await item.getData();
        if (bytes != null) {
          embeddings[rollNo] = _bytesToEmbeddings(bytes);
        }
      }

      return embeddings;
    } catch (e) {
      throw Exception('Failed to download department embeddings: $e');
    }
  }

  /// Delete embeddings
  Future<void> deleteEmbeddings({
    required String rollNo,
    required String dept,
    required String batch,
    required String branch,
  }) async {
    try {
      final path = 'embeddings/$dept/$batch/$branch/$rollNo.bin';
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete embeddings: $e');
    }
  }

  /// Convert embeddings to bytes
  /// Format: 3 embeddings × 128 floats = 384 floats (1536 bytes)
  Uint8List _embeddingsToBytes(List<List<double>> embeddings) {
    final buffer = ByteData(embeddings.length * 128 * 4); // 4 bytes per float
    var offset = 0;

    for (final embedding in embeddings) {
      for (final value in embedding) {
        buffer.setFloat32(offset, value, Endian.little);
        offset += 4;
      }
    }

    return buffer.buffer.asUint8List();
  }

  /// Convert bytes back to embeddings
  List<List<double>> _bytesToEmbeddings(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);
    final embeddings = <List<double>>[];

    var offset = 0;
    while (offset < bytes.length) {
      final embedding = <double>[];
      for (var i = 0; i < 128; i++) {
        embedding.add(buffer.getFloat32(offset, Endian.little));
        offset += 4;
      }
      embeddings.add(embedding);
    }

    return embeddings;
  }

  /// Get download URL for debugging
  Future<String> getDownloadUrl({
    required String rollNo,
    required String dept,
    required String batch,
    required String branch,
  }) async {
    final path = 'embeddings/$dept/$batch/$branch/$rollNo.bin';
    final ref = _storage.ref().child(path);
    return await ref.getDownloadURL();
  }
}
