import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import '../../verification/presentation/verification_result_widget.dart';
import '../../verification/presentation/face_enrollment_screen.dart';
import '../../../data/providers/verification_provider.dart'; // New provider
import '../../../core/theme/app_colors.dart';
import '../../../core/services/qr_service.dart';
import '../data/event_repository.dart';

import '../../../../domain/entities/student.dart'; // import Entity
import '../domain/team_model.dart';
import '../../guests/domain/guest_model.dart';
import '../../verification/data/verification_repository.dart';
import '../../events/domain/event_model.dart';

enum ScanMode { studentId, guestQr, team }

class EventCheckInScreen extends ConsumerStatefulWidget {
  final Event event;
  const EventCheckInScreen({super.key, required this.event});

  @override
  ConsumerState<EventCheckInScreen> createState() => _EventCheckInScreenState();
}

class _EventCheckInScreenState extends ConsumerState<EventCheckInScreen> {
  bool _isScanning = true;
  ScanMode _scanMode = ScanMode.studentId;

  // Results
  Student? _foundStudent;
  ExternalGuest? _foundGuest;
  List<Team>? _foundTeams;

  XFile? _livePhoto;
  VerificationState _verificationState = VerificationState.idle;
  String? _verificationMessage;

  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _isScanning) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        if (_scanMode == ScanMode.guestQr) {
          _verifyGuestQr(code);
        } else {
          _fetchEntity(code);
        }
      }
    }
  }

  // --- Logic Implementations ---

  Future<void> _fetchEntity(String code) async {
    setState(() => _isScanning = false);

    try {
      if (_scanMode == ScanMode.studentId) {
        final student = await ref
            .read(eventRepositoryProvider)
            .getStudentByRollNumber(code);
        if (student != null) {
          setState(() {
            _foundStudent = student;
            _verificationState = VerificationState.idle;
          });
        } else {
          _showErrorSnackBar("Student not found");
          setState(() => _isScanning = true);
        }
      }
      // Team Scanning (if logic supported scanning leader ID)
      else if (_scanMode == ScanMode.team) {
        // Use search for teams instead
        setState(() => _isScanning = true);
      }
    } catch (e) {
      _showErrorSnackBar("Error: ${e.toString()}");
      setState(() => _isScanning = true);
    }
  }

  Future<void> _verifyGuestQr(String payload) async {
    setState(() => _isScanning = false);

    // 1. Verify Logic
    final result = await ref
        .read(verificationRepositoryProvider)
        .verifyGuestQr(payload);

    if (result == QrValidationResult.success) {
      final guest = await ref
          .read(verificationRepositoryProvider)
          .getGuest(payload);
      setState(() {
        _foundGuest = guest;
        _verificationState =
            VerificationState.success; // No face-match for guests usually
        _verificationMessage = "Valid Ticket";
      });
    } else {
      _showErrorSnackBar("Entry Denied: ${result.name.toUpperCase()}");
      setState(() => _isScanning = true);
    }
  }

  Future<void> _searchTeams(String query) async {
    setState(() => _isScanning = false);
    final teams = await ref
        .read(verificationRepositoryProvider)
        .searchTeams(widget.event.id, query);
    setState(() {
      _foundTeams = teams;
    });
  }

  // --- Face Match Logic (Student Only) ---

  Future<void> _takeLivePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );

    if (photo != null) {
      setState(() {
        _livePhoto = photo;
        _verificationState = VerificationState.loading;
        _verificationMessage = "Matching Face...";
      });

      try {
        final result = await ref
            .read(verificationServiceProvider)
            .verifyStudent(student: _foundStudent!, livePhoto: photo);

        if (mounted) {
          setState(() {
            _verificationState = result.isMatch
                ? VerificationState.success
                : VerificationState.failure;
            _verificationMessage = result.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _verificationState = VerificationState.failure;
            _verificationMessage = "System Error: ${e.toString()}";
          });
        }
      }
    }
  }

  // --- Actions ---

  void _completeCheckIn() async {
    if (_foundStudent != null) {
      await ref
          .read(eventRepositoryProvider)
          .checkInStudent(
            widget.event.id,
            _foundStudent!.rollNo,
          ); // rollNumber -> id
      _showSuccessSnackBar('${_foundStudent!.name} Checked In!');
    } else if (_foundGuest != null) {
      // Guest Check-in (Mock)
      _showSuccessSnackBar('${_foundGuest!.name} Admitted!');
    }
    _reset();
  }

  void _completeTeamCheckIn(Team team) async {
    // Check in all members? Or just mark team as present?
    // For now just success msg
    _showSuccessSnackBar('${team.name} Checked In!');
    _reset();
  }

  void _manualOverride() {
    _completeCheckIn();
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _foundStudent = null;
        _foundGuest = null;
        _foundTeams = null;
        _livePhoto = null;
        _verificationState = VerificationState.idle;
        _verificationMessage = null;
      });
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccessSnackBar(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _scanMode == ScanMode.team ? 'Search Team Name' : 'Enter ID',
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_scanMode == ScanMode.team) {
                _searchTeams(controller.text);
              } else {
                _fetchEntity(controller.text);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Check-in: ${widget.event.title}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: Column(
        children: [
          // Mode Selector
          Container(
            color: Colors.grey.shade100,
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildModeChip(ScanMode.studentId, "Student ID", Icons.badge),
                const SizedBox(width: 8),
                _buildModeChip(ScanMode.guestQr, "Guest Ticket", Icons.qr_code),
                const SizedBox(width: 8),
                _buildModeChip(ScanMode.team, "Team Search", Icons.group),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildModeChip(ScanMode mode, String label, IconData icon) {
    final isSelected = _scanMode == mode;
    return ChoiceChip(
      label: Row(
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _scanMode = mode;
            _reset();
          });
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black,
      ),
    );
  }

  Widget _buildBody() {
    if (_foundTeams != null) {
      return ListView.builder(
        itemCount: _foundTeams!.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (ctx, i) {
          final team = _foundTeams![i];
          return Card(
            child: ListTile(
              title: Text(
                team.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Leader: ${team.leaderRollNumber} (${team.memberRollNumbers.length} members)",
              ),
              trailing: ElevatedButton(
                onPressed: () => _completeTeamCheckIn(team),
                child: const Text("Check In"),
              ),
            ),
          );
        },
      );
    }

    if (_isScanning && _scanMode != ScanMode.team) {
      return Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _scanMode == ScanMode.guestQr
                      ? "Scan Guest QR"
                      : "Scan Student ID",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 0,
            left: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.keyboard),
                label: const Text("Enter Manually"),
                onPressed: _showManualEntryDialog,
              ),
            ),
          ),
        ],
      );
    } else if (_scanMode == ScanMode.team && _isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Search Team by Name"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showManualEntryDialog,
              child: const Text("Search Team"),
            ),
          ],
        ),
      );
    }

    // Found Entity Display
    if (_foundStudent != null) return _buildStudentProfile(_foundStudent!);
    if (_foundGuest != null) return _buildGuestProfile(_foundGuest!);

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildGuestProfile(ExternalGuest guest) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              Text(
                guest.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(guest.email),
              const SizedBox(height: 20),
              const Chip(
                label: Text("Valid Ticket"),
                backgroundColor: Colors.greenAccent,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _completeCheckIn,
                child: const Text("Admit Guest"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentProfile(Student student) {
    // Same as before but modularized
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _foundStudent!.photoUrl.isNotEmpty
                      ? NetworkImage(_foundStudent!.photoUrl)
                      : const AssetImage(
                              'assets/images/student_placeholder.png',
                            )
                            as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(student.rollNo), // rollNumber -> id
                const Divider(height: 32),
                if (widget.event.requiresLiveVerification)
                  _buildVerificationSection(),

                // Registration Option
                TextButton.icon(
                  onPressed: () async {
                    final success = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FaceEnrollmentScreen(student: student),
                      ),
                    );
                    if (success == true) {
                      _showSuccessSnackBar(
                        "Face Registered! Try verifying again.",
                      );
                      // Optionally reset state to force re-verification
                      setState(() {
                        _verificationState = VerificationState.idle;
                        _livePhoto = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text("Register Face (Enroll)"),
                ),

                if (!widget.event.requiresLiveVerification)
                  ElevatedButton(
                    onPressed: _completeCheckIn,
                    child: const Text("Check In"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    // Identical to previous implementation
    if (_verificationState == VerificationState.idle) {
      return ElevatedButton.icon(
        onPressed: _takeLivePhoto,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Verify Identity'),
      );
    }
    return Column(
      children: [
        if (_livePhoto != null) Image.file(File(_livePhoto!.path), height: 150),
        VerificationResultWidget(
          state: _verificationState,
          message: _verificationMessage,
          onRetry: _takeLivePhoto,
          onManualOverride: _manualOverride,
        ),
        if (_verificationState == VerificationState.success)
          ElevatedButton(
            onPressed: _completeCheckIn,
            child: const Text("Next"),
          ),
      ],
    );
  }
}
