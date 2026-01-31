import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:svce/features/auth/state/auth_provider.dart';
// import '../../auth/state/auth_provider.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Welcome Student!'),
            SizedBox(height: 20),
            // Mock Community Cards Logic would go here
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('GDG Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
