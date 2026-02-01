import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/discipline_case.dart';
import '../../../data/providers/discipline_provider.dart';
import '../../../data/providers/student_provider.dart';
import '../../discipline/presentation/create_case_flow.dart';
import '../../discipline/presentation/case_detail_screen.dart';

class StudentPreviewScreen extends ConsumerStatefulWidget {
  final Student student;

  const StudentPreviewScreen({super.key, required this.student});

  @override
  ConsumerState<StudentPreviewScreen> createState() =>
      _StudentPreviewScreenState();
}

class _StudentPreviewScreenState extends ConsumerState<StudentPreviewScreen> {
  late Future<List<DisciplineCase>> _historyFuture;
  late int _currentCredits;

  @override
  void initState() {
    super.initState();
    _currentCredits = widget.student.credits;
    _refreshStudentData(); // Fetch latest data immediately
    _loadHistory();
  }

  Future<void> _refreshStudentData() async {
    try {
      DocumentSnapshot? snapshot;

      // 1. Try using the known path first
      if (widget.student.firestorePath != null &&
          widget.student.firestorePath!.isNotEmpty) {
        snapshot = await FirebaseFirestore.instance
            .doc(widget.student.firestorePath!)
            .get();
      }

      // 2. Fallback: If path failed or unavailable, search for the student
      if (snapshot == null || !snapshot.exists) {
        final query = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('rollNo', isEqualTo: widget.student.rollNo)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          snapshot = query.docs.first;
        }
      }

      // 3. Update state if data found
      if (snapshot != null && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('credits')) {
          final freshCredits = (data['credits'] as num).toInt();
          if (mounted) {
            setState(() {
              _currentCredits = freshCredits;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing student data: $e');
    }
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = ref
          .read(disciplineRepositoryProvider)
          .getHistory(widget.student.rollNo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Student Photo
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 4),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: widget.student.photoUrl.isNotEmpty
                        ? NetworkImage(widget.student.photoUrl)
                        : const AssetImage(
                                'assets/images/student_placeholder.png',
                              )
                              as ImageProvider,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name & IDCard
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      widget.student.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.student.rollNo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Credits Badge
                    GestureDetector(
                      onLongPress: () => _confirmResetCredits(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _currentCredits < 50
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentCredits < 50
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stars,
                              size: 20,
                              color: _currentCredits < 50
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Credits: $_currentCredits/100',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _currentCredits < 50
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    _buildInfoRow(context, 'Course', widget.student.course),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Branch', widget.student.branch),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Year', widget.student.year),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Section', widget.student.section),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Discipline History Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discipline History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _loadHistory();
                    _refreshStudentData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<DisciplineCase>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final cases = snapshot.data ?? [];

                if (cases.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No past disciplinary cases.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                }

                return Column(
                  children: [
                    Text(
                      '${cases.length} Total Cases',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cases.take(3).map((c) => _buildCaseItem(context, c)),
                    if (cases.length > 3)
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Mark Late Entry Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final disciplineRepo = ref.read(
                      disciplineRepositoryProvider,
                    );
                    // 1. Define Case
                    final newCase = DisciplineCase(
                      id: '',
                      studentId: widget.student.rollNo,
                      category: 'Administrative Services',
                      subCategory: 'Late Arrival',
                      subject: 'Late Entry',
                      description: 'Marked late via Security Scanner',
                      severity: 'Normal',
                      timestamp: DateTime.now(),
                      reportedBy: 'Security',
                      pointsDeducted:
                          5, // Explicitly suggesting 5, though backend defaults to 5 for Normal
                    );

                    // 2. Execute via Repository (Transaction handles credits)
                    await disciplineRepo.raiseCase(newCase);
                    ref.invalidate(facultyHistoryProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Marked as Late. 5 Points deducted.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      // 3. Refresh UI
                      _loadHistory();
                      _refreshStudentData();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.access_time_filled),
                label: const Text('Mark Late Entry (-5 Credits)'),
              ),
            ),
            const SizedBox(height: 16),

            // Raise Case Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Navigate to Create Case Flow
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) =>
                          CreateCaseFlow(studentId: widget.student.rollNo),
                    ),
                  );
                  if (result == true) {
                    _loadHistory(); // Refresh
                    _refreshStudentData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Raise Disciplinary Case'),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCaseItem(BuildContext context, DisciplineCase c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.warning,
          color: c.severity == 'High' ? Colors.red : Colors.orange,
        ),
        title: Text(
          c.subject,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${c.timestamp.year}-${c.timestamp.month.toString().padLeft(2, '0')}-${c.timestamp.day.toString().padLeft(2, '0')}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.pointsDeducted != null && c.pointsDeducted! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '-${c.pointsDeducted}',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.grey,
              ),
              onPressed: () => _confirmDelete(c),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaseDetailScreen(disciplineCase: c),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(DisciplineCase c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Case?'),
        content: const Text(
          'This will remove the case and RESTORE the deducted credits (if any).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final disciplineRepo = ref.read(disciplineRepositoryProvider);
        await disciplineRepo.deleteCase(c.id, c.studentId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Case deleted and credits restored.')),
          );
          _loadHistory();
          _refreshStudentData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting case: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmResetCredits() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Credits?'),
        content: const Text(
          'This will manually reset the student\'s credits to 100/100. Use this only to correct data errors.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final disciplineRepo = ref.read(disciplineRepositoryProvider);
        await disciplineRepo.resetCredits(widget.student.rollNo);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credits reset to 100 successfully.')),
          );
          _refreshStudentData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting credits: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
