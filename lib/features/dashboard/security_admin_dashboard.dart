import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/state/auth_provider.dart';

class SecurityAdminDashboard extends ConsumerWidget {
  const SecurityAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock security data
    final securityList = [
      {
        'name': 'Officer John Doe',
        'id': 'SEC-001',
        'post': 'Main Gate',
        'status': 'On Duty',
      },
      {
        'name': 'Officer Jane Smith',
        'id': 'SEC-002',
        'post': 'Library Block',
        'status': 'Patrolling',
      },
      {
        'name': 'Officer Mike Ross',
        'id': 'SEC-003',
        'post': 'Canteen Area',
        'status': 'On Break',
      },
      {
        'name': 'Officer Sarah Log',
        'id': 'SEC-004',
        'post': 'Parking Lot',
        'status': 'On Duty',
      },
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF263238), Color(0xFF37474F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Command',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[100],
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Personnel Status',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Security List
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFECEFF1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF455A64),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Manage Securities',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF37474F),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      // Raise Dispute Logic
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Raise Dispute / Override initiated',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.report_problem,
                                      color: Colors.orange,
                                    ),
                                    tooltip: 'Raise Dispute / Override',
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF455A64),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${securityList.length} Active',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: ListView.builder(
                              itemCount: securityList.length,
                              itemBuilder: (context, index) {
                                final guard = securityList[index];
                                final isDuty = guard['status'] == 'On Duty';
                                final isPatrol =
                                    guard['status'] == 'Patrolling';
                                Color statusColor = isDuty
                                    ? Colors.green
                                    : (isPatrol ? Colors.blue : Colors.orange);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueGrey.withOpacity(0.1),
                                        spreadRadius: 2,
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(
                                        2,
                                      ), // Border width
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor, // Border color based on status
                                        shape: BoxShape.circle,
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.white,
                                        backgroundImage: const AssetImage(
                                          'assets/images/securityavatar.png',
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      guard['name']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF263238),
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            guard['post']!,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          guard['status']!,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          guard['id']!,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      // Monitor guard activity
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scanner'),
        backgroundColor: const Color(0xFF263238),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Scan Student',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
