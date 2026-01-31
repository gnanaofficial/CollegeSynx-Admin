import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/discipline_case.dart';
import '../../../data/repositories/mock_discipline_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    // In a real app we might use a provider with autodispose, but for this preview screen,
    // simple future is fine or a provider that takes family.
    // We'll use the repository provider directly here for simplicity in this flow.
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
                // Maybe a refresh button?
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadHistory,
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
        subtitle: Text(c.timestamp.toString().split(' ')[0]), // Simple date
        trailing: const Icon(Icons.chevron_right),
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
}
