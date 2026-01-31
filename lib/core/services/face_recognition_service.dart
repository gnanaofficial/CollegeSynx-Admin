import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  Interpreter? _interpreter;

  // MobileFaceNet Expects 112x112 input
  static const int inputSize = 112;
  // Output embedding size (usually 128 or 192 for MobileFaceNet)
  static const int outputSize = 128; // Verify model first!

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();
      // Use XNNPACK or GPU delegate if improving performance needed
      // options.addDelegate(XNNPackDelegate());

      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
        options: options,
      );

      print('✅ Face Recognition Model Loaded');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  /// Generate embedding vector for a face image
  /// Image must be cropped to the face already
  Future<List<double>> generateEmbedding(img.Image faceImage) async {
    if (_interpreter == null) await initialize();

    // 1. Get Model Constraints
    final inputT = _interpreter!.getInputTensor(0);
    final outputT = _interpreter!.getOutputTensor(0);

    final inShape = inputT.shape; // e.g. [1, 112, 112, 3]
    final outShape = outputT.shape; // e.g. [1, 128] or [1, 192]

    // Validate Input Size
    if (inShape[1] != inputSize || inShape[2] != inputSize) {
      print(
        "⚠️ Model expects ${inShape[1]}x${inShape[2]}, but code uses $inputSize",
      );
    }

    // 2. Preprocess
    final resizedImage = img.copyResize(
      faceImage,
      width: inputSize,
      height: inputSize,
    );

    // 3. Normalize & Reshape
    // Convert to 4D List [1, 112, 112, 3] as expected by standard run()
    // Using explicit List structure avoids shape mismatch errors with flat buffers
    // Note: This matches the 'reshape' logic but ensures List<dynamic> compatibility
    var inputValues = _imageTo4DList(resizedImage);

    // 4. Output buffer
    // Allocate exactly what the model asks for
    var outputBuffer = List.filled(
      outShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outShape);

    // 5. Run inference
    _interpreter!.run(inputValues, outputBuffer);

    // 6. flatten and return
    return List<double>.from(outputBuffer[0]);
  }

  // Helper to create 4D list [1, 112, 112, 3] from image
  List<List<List<List<double>>>> _imageTo4DList(img.Image image) {
    var list = List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          var pixel = image.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        }),
      ),
    );
    return list;
  }

  /// Compare two face embeddings using Cosine Similarity
  /// Returns similarity score (0.0 to 1.0)
  /// > 0.70 usually means match (tune this threshold!)
  double compareEmbeddings(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
      normA += emb1[i] * emb1[i];
      normB += emb2[i] * emb2[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Euclidean distance (Lower is better)
  double euclideanDistance(List<double> emb1, List<double> emb2) {
    double sum = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      sum += pow(emb1[i] - emb2[i], 2);
    }
    return sqrt(sum);
  }
}
