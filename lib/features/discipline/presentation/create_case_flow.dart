import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/discipline_case.dart';
import '../../../data/repositories/mock_discipline_repository.dart';

class CreateCaseFlow extends ConsumerStatefulWidget {
  final String studentId;
  const CreateCaseFlow({super.key, required this.studentId});

  @override
  ConsumerState<CreateCaseFlow> createState() => _CreateCaseFlowState();
}

class _CreateCaseFlowState extends ConsumerState<CreateCaseFlow> {
  int _step = 1;

  // Step 1: Category
  String _selectedCategory = ''; // Academic Affairs, IT Support, Administrative
  String _selectedSubCategory = '';
  final _picker = ImagePicker();

  // Step 2: Details
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _urgency = 'Normal';
  final DateTime _selectedDate = DateTime.now();

  // Step 3: Evidence
  File? _capturedImage;
  bool _isSubmitting = false;

  void _nextStep() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submitCase();
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _showEvidenceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Upload from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Permission Handling
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos.'),
          ),
        );
        return;
      }
    }
    // Gallery permission is generally handled by image_picker plugin manifest on Android

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  Future<void> _submitCase() async {
    setState(() => _isSubmitting = true);

    final newCase = DisciplineCase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: widget.studentId,
      category: _selectedCategory,
      subCategory: _selectedSubCategory,
      subject: _subjectController.text,
      description: _descriptionController.text,
      severity: _urgency,
      timestamp: _selectedDate,
      reportedBy: 'Faculty (You)',
      proofImagePath: _capturedImage?.path,
    );

    await ref.read(disciplineRepositoryProvider).raiseCase(newCase);
    ref.invalidate(facultyHistoryProvider); // Refresh history list

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  bool _canProceed() {
    if (_step == 1) return _selectedCategory.isNotEmpty;
    if (_step == 2) {
      return _subjectController.text.isNotEmpty &&
          _selectedSubCategory.isNotEmpty;
    }
    // Step 3 is review, always can submit unless blocked
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_stepTitle()),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _step / 3,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  String _stepTitle() {
    if (_step == 1) return 'New Case';
    if (_step == 2) return 'Case Details';
    return 'Review Summary';
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildCategorySelection();
      case 2:
        return _buildCaseDetailsForm();
      case 3:
        return _buildReviewSummary();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 1: Category ---
  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What kind of assistance do you need today?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a category to get started.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
        const SizedBox(height: 32),
        _buildCategoryCard(
          'Academic Affairs',
          Icons.school,
          'Grades, curriculum, attendance',
        ),
        _buildCategoryCard(
          'IT & Technical Support',
          Icons.wifi,
          'Login issues, Wi-Fi, hardware',
        ),
        _buildCategoryCard(
          'Administrative Services',
          Icons.location_city,
          'Fees, hostel, transport',
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, String subtitle) {
    final isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = title;
          _selectedSubCategory = ''; // Reset sub-category on change
        });
        // Requirement says "On selecting... Navigate to Step 2".
        // We can do auto-nav or wait for Next. Let's auto-nav to be smooth like the design implies.
        Future.delayed(const Duration(milliseconds: 200), _nextStep);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Details ---
  Widget _buildCaseDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReadOnlyField('SELECTED CASE TYPE', _selectedCategory),
        const SizedBox(height: 24),

        // Sub-Category Dropdown
        const Text(
          'Sub-Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select Sub-Category'),
              value: _selectedSubCategory.isEmpty ? null : _selectedSubCategory,
              items: _getSubCategories(_selectedCategory).map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),
              onChanged: (v) => setState(() => _selectedSubCategory = v!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Subject', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectController,
          decoration: InputDecoration(
            hintText: 'e.g., Missing Grade in Physics',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}), // rebuild for validation
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Urgency',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _urgency,
                        isExpanded: true,
                        items: ['Normal', 'High']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _urgency = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Detailed Description',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the incident...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        // Evidence Add Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showEvidenceOptions,
            icon: const Icon(Icons.add_a_photo),
            label: Text(
              _capturedImage == null
                  ? 'Add Evidence (Optional)'
                  : 'Change Evidence',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_capturedImage != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: FileImage(_capturedImage!),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.school, size: 18, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Review ---
  Widget _buildReviewSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'Final Check Required\nSubmitted cases cannot be edited immediately.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSummarySection('Case Basics', [
          _buildDetailRow('TITLE', _subjectController.text),
          const SizedBox(height: 12),
          _buildDetailRow('CATEGORY', _selectedCategory),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow('SUB-CATEGORY', _selectedSubCategory),
              ),
              Expanded(
                child: _buildDetailRow('PRIORITY', _urgency, isBadge: true),
              ),
            ],
          ),
        ], onEdit: () => setState(() => _step = 2)),
        const SizedBox(height: 16),
        _buildSummarySection('Description', [
          Text(
            _descriptionController.text.isEmpty
                ? 'No description provided.'
                : _descriptionController.text,
            style: const TextStyle(fontSize: 14),
          ),
        ], onEdit: () => setState(() => _step = 2)),
        const SizedBox(height: 16),
        _buildSummarySection('Evidence', [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capturedImage == null
                            ? 'No Evidence Uploaded'
                            : 'image_capture.jpg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_capturedImage != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageViewer(
                                  imagePath: _capturedImage!.path,
                                  tag: 'review_evidence',
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'review_evidence',
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: FileImage(_capturedImage!),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_capturedImage != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildSummarySection(
    String title,
    List<Widget> children, {
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (onEdit != null)
                TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        isBadge
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: value == 'High'
                      ? AppColors.error.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: value == 'High' ? AppColors.error : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 1) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting || !_canProceed() ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _step == 3 ? 'Submit Case' : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSubCategories(String category) {
    switch (category) {
      case 'Academic Affairs':
        return ['Grades', 'Attendance', 'Curriculum', 'Exam Issue'];
      case 'IT & Technical Support':
        return [
          'Wi-Fi Connectivity',
          'Login Issue',
          'Portal Error',
          'Hardware',
        ];
      case 'Administrative Services':
        return ['Hostel', 'Transport', 'ID Card', 'Fees'];
      default:
        return ['General'];
    }
  }
}
