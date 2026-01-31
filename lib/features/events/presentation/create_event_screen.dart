import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../data/event_repository.dart';
import '../domain/event_model.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  bool _requiresLiveVerification = false;
  EventType _eventType = EventType.individual;
  EventAccessType _accessType = EventAccessType.studentsOnly;

  File? _csvFile;
  String? _csvFileName;
  bool _isImporting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _csvFile = File(result.files.single.path!);
          _csvFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  void _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isImporting = true);

      try {
        final newEventId = DateTime.now().millisecondsSinceEpoch.toString();

        final newEvent = Event(
          id: newEventId,
          title: _titleController.text,
          description: _descController.text,
          date: DateTime.now(), // In real app, pick date
          location: _locationController.text,
          requiresLiveVerification: _requiresLiveVerification,
          eventType: _eventType,
          accessType: _accessType,
        );

        // 1. Save Event
        await ref.read(eventRepositoryProvider).addEvent(newEvent);

        // 2. Import CSV if Selected
        if (_csvFile != null) {
          final result = await ref
              .read(eventRepositoryProvider)
              .importRegistrationsFromCsv(_csvFile!, newEventId);

          if (!mounted) return;

          if (!result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Event Created but Import Failed: ${result.message}',
                ),
              ),
            );
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Event Title',
                icon: Icons.title,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Location',
                icon: Icons.location_on,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 24),
              const Text(
                "Event Config",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Event Type Dropdown
              DropdownButtonFormField<EventType>(
                value: _eventType,
                decoration: _inputDecoration('Event Category', Icons.category),
                items: const [
                  DropdownMenuItem(
                    value: EventType.individual,
                    child: Text('Individual Event'),
                  ),
                  DropdownMenuItem(
                    value: EventType.team,
                    child: Text('Team Event / Hackathon'),
                  ),
                ],
                onChanged: (val) => setState(() => _eventType = val!),
              ),
              const SizedBox(height: 16),

              // Access Type Dropdown
              DropdownButtonFormField<EventAccessType>(
                value: _accessType,
                decoration: _inputDecoration('Access Scope', Icons.public),
                items: const [
                  DropdownMenuItem(
                    value: EventAccessType.studentsOnly,
                    child: Text('Students Only (ID Card)'),
                  ),
                  DropdownMenuItem(
                    value: EventAccessType.public,
                    child: Text('Open to Public (Guests)'),
                  ),
                ],
                onChanged: (val) => setState(() => _accessType = val!),
              ),

              const SizedBox(height: 24),

              // File Picker
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Import Participants (CSV)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Upload Google Form Export (Team or Individuals)",
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 12),
                    if (_csvFile != null)
                      Chip(
                        label: Text(_csvFileName!),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () => setState(() {
                          _csvFile = null;
                          _csvFileName = null;
                        }),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _pickCsvFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Select CSV File"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Toggle for Live Verification
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require Live Face Verification'),
                subtitle: const Text('Force biometric match at check-in'),
                value: _requiresLiveVerification,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _requiresLiveVerification = val;
                  });
                },
              ),

              const SizedBox(height: 40),

              if (_isImporting)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Event',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
