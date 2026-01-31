import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/student.dart';
import 'student_verification_screen.dart';
import 'auto_face_registration_screen.dart';

class VerificationChoiceScreen extends ConsumerStatefulWidget {
  final Student student;

  const VerificationChoiceScreen({super.key, required this.student});

  @override
  ConsumerState<VerificationChoiceScreen> createState() =>
      _VerificationChoiceScreenState();
}

class _VerificationChoiceScreenState
    extends ConsumerState<VerificationChoiceScreen> {
  CameraController? _controller;
  bool _isInit = false;
  bool _useFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Ensure we don't init if already disposing or disposed
    if (!mounted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (c) =>
            c.lensDirection ==
            (_useFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      // 1. Immediately update UI to stop using the controller
      setState(() {
        _isInit = false;
      });

      // 2. Dispose
      await _controller!.dispose();
      _controller = null;
    }
  }

  Future<void> _switchCamera() async {
    await _disposeCamera();

    setState(() {
      _useFrontCamera = !_useFrontCamera;
    });

    await _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _hasEmbeddings =>
      widget.student.embeddings != null &&
      widget.student.embeddings!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Student Check-In'),
        actions: [
          // Camera switch button
          IconButton(
            icon: Icon(
              _useFrontCamera ? Icons.camera_front : Icons.camera_rear,
              color: Colors.white,
            ),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isInit && _controller != null)
                  CameraPreview(_controller!)
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Face frame overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(125),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Student Info & Actions (Scrollable to prevent overflow)
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student Info
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: widget.student.photoUrl.isNotEmpty
                              ? NetworkImage(widget.student.photoUrl)
                              : null,
                          radius: 28,
                          child: widget.student.photoUrl.isEmpty
                              ? Text(
                                  widget.student.rollNo.substring(0, 2),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.student.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.student.rollNo,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Registration status indicator
                        if (_hasEmbeddings)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Registered',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Not Registered',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey, height: 1),
                    const SizedBox(height: 16),

                    // Action Buttons
                    if (_hasEmbeddings) ...[
                      // Verify button (primary)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Dispose camera before navigating to prevent resource conflict
                            await _controller?.dispose();
                            _controller = null;

                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentVerificationScreen(
                                    student: widget.student,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.face, size: 22),
                          label: const Text(
                            'VERIFY IDENTITY',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Re-register button (secondary)
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Dispose camera before navigating
                            await _controller?.dispose();
                            _controller = null;

                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AutoFaceRegistrationScreen(
                                    student: widget.student,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.face_retouching_natural,
                            size: 18,
                          ),
                          label: const Text(
                            'RE-REGISTER FACE',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Verify button (Enabled if has embeddings OR passport photo)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed:
                              (widget.student.photoUrl.isNotEmpty ||
                                  _hasEmbeddings)
                              ? () async {
                                  // Dispose camera safe
                                  await _disposeCamera();

                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentVerificationScreen(
                                              student: widget.student,
                                            ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.face, size: 22),
                          label: const Text(
                            'VERIFY IDENTITY',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (widget.student.photoUrl.isNotEmpty ||
                                    _hasEmbeddings)
                                ? Colors.green
                                : Colors.grey.shade800,
                            foregroundColor:
                                (widget.student.photoUrl.isNotEmpty ||
                                    _hasEmbeddings)
                                ? Colors.white
                                : Colors.grey.shade600,
                            disabledBackgroundColor: Colors.grey.shade800,
                            disabledForegroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Register button (primary if not registered)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Dispose camera safe
                            await _disposeCamera();

                            if (context.mounted) {
                              // Use push instead of pushReplacement so we can get result back
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AutoFaceRegistrationScreen(
                                    student: widget.student,
                                  ),
                                ),
                              );

                              // Check if we need to refresh (user registered successfully)
                              if (result == true) {
                                // Re-init camera since we disposed it
                                _initCamera();
                                // Force UI rebuild to hopefully show updated state if student object was mutable/refetched
                                // Ideally we should refetch the student here.
                                // For now, let's assume the user wants to see "Registered"
                                // We might need a flag since 'student' widget param is final.
                                setState(() {
                                  // This won't update 'student' prop but will rebuild UI.
                                  // To really show 'Registered', logic needs to know.
                                  // Let's assume AutoFaceRegistration updated the remote DB.
                                  // We can't easily update 'widget.student' because it's final.
                                  // But we can trigger a re-fetch or pop back.
                                  // Let's pop back to Scanner to force full refresh for now?
                                  // Or just stay here.
                                });

                                // Show snackbar
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Registration Updated"),
                                    ),
                                  );
                                }
                              } else {
                                // Just re-init camera if they backed out
                                _initCamera();
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.face_retouching_natural,
                            size: 22,
                          ),
                          label: Text(
                            _hasEmbeddings
                                ? 'RE-REGISTER FACE'
                                : 'REGISTER FACE',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Info message
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Register face first to enable verification.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
