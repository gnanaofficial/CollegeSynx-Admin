import 'package:flutter/services.dart';

import 'package:minio/minio.dart';

class ImageStorageService {
  late Minio _minio;
  final String bucketName = 'students';
  final String accountId = '40530319104a4ad8416b12c120370b45';

  // Endpoint for Cloudflare R2: https://<accountid>.r2.cloudflarestorage.com
  String get _endpoint => '$accountId.r2.cloudflarestorage.com';

  ImageStorageService() {
    _minio = Minio(
      endPoint: _endpoint,
      accessKey: '4860a9b948aa670d3b9a6ad1a4762b5c',
      secretKey:
          '5d8cd9ebf404d52061b50b16635831afb36adfb72f309340005857511ab43c0c',
      useSSL: true,
      // Region is generally 'auto' for R2, but minio might default to us-east-1 if not specified.
      // Cloudflare R2 usually ignores region, but we can pass one.
      region: 'auto',
    );
  }

  Future<String?> uploadImage(
    String rollNumber,
    String assetPath, {
    String folderPath = 'images', // Default folder
  }) async {
    try {
      // 1. Load asset bytes
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final Stream<Uint8List> stream = Stream.value(bytes);

      final String fileName = '$folderPath/$rollNumber.jpeg'; // Use folderPath

      final int size = bytes.length;

      // 2. Upload to R2
      await _minio.putObject(
        bucketName,
        fileName,
        stream,
        size: size,
        metadata: {'content-type': 'image/jpeg'},
      );
      print(
        'Upload progress: completed',
      ); // Basic logging as onProgress might be unsupported

      // 3. Return Public URL (or Custom Domain URL)
      // If user has a public domain mapped: https://pub-domain/$fileName
      // Otherwise, the S3 signed URL, but here we probably want to store a reference.
      // For now, let's return a constructed URL or just the fileName.
      // Cloudflare R2 Public URLs format if enabled: https://pub-<hash>.r2.dev/$fileName

      // Since we don't have the public domain, we'll return the fileName.
      // The app will need to generate a presigned URL to view it, or use a worker.
      // Let's print the presigned URL for debug.
      final url = await _minio.presignedGetObject(bucketName, fileName);
      print('Uploaded $fileName. Presigned URL: $url');

      // Return the Public URL
      return 'https://pub-3d6d4bb627f0412ea00d3ccda8b45b29.r2.dev/$fileName';
    } catch (e) {
      print('Error uploading image to R2: $e');
      if (e.toString().contains('NoSuchBucket')) {
        print('Attempting to create bucket...');
        try {
          await _minio.makeBucket(bucketName);
          // Retry upload ...
        } catch (e2) {
          print('Failed to create bucket: $e2');
        }
      }
      return null;
    }
  }
}
