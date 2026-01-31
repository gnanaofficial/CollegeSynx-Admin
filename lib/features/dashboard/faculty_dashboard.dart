import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/state/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../history/presentation/history_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../events/presentation/events_screen.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});

  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  int _selectedIndex = 0;

  // Pages for Bottom Nav
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _HomeContent(), // Home
      // Use HistoryScreen for Activity tab
      const HistoryScreen(),
      const ProfileScreen(), // Profile
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Use SafeArea inside body pages instead of wrapping body to allow status bar color control if needed
      // But _HomeContent uses SafeArea or standard padding.
      // To avoid interaction overlap with floating FAB dock, we can rely on properly sized padding in pages or use extendBody: false (default).
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: Colors.white,
        elevation: 8,
        height: 70,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Side: Home
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
                    // If we want 4 items balance, we need another item here or just space.
                    // The user asked to remove "Message".
                    // So we have 3 items: Home, FAB, Activity, Profile.
                    // A balanced layout with center FAB needs even items on sides.
                    // Let's put Home on Left. Activity and Profile on Right?
                    // Or Home and Activity on Left?
                    // If we do: Home, Activity, FAB, Profile -> Unbalanced.
                    // Standard 3 items with FAB:
                    // 1. Home, Activity -- FAB -- Profile (Weird)
                    // 2. Home -- FAB -- Activity, Profile (Weird)
                    // 3. Home -- FAB -- Activity -- Profile (4 slots, 1 empty?)
                    // Let's stick to the visual provided/standard:
                    // Home (Left), Activity (Right), Profile (Right-most).
                    // Wait, if 3 items, usually FAB is not centered docking if items are odd.
                    // Let's try:
                    // Left: Home. Right: Activity, Profile.
                    // And a gap in middle.
                    // Left: [Home, Gap] -- Right: [Activity, Profile]
                    // This balances 2 items on comparison to FAB.
                    // Actually let's do:
                    // [Home] ----- [FAB] ----- [Activity] ----- [Profile]
                    // This looks bad.
                    // Let's Try:
                    // [Home] [Activity] --- FAB --- [Profile] ?
                    // The provided design (screenshots) usually have 4 items: Home|Scan|Activity|Profile
                    // If Scan is the FAB, then: Home | Activity | Profile?
                    // Let's assume the user wants:
                    // Home, Activity --- FAB --- Profile.
                    // Let's try to balance it by spacing.
                    // Or maybe: Home, Activity, Profile. And FAB is floating above?
                    // "navigation bar is overlapped" -> suggests FAB dock issue.
                    // Let's Use:
                    // Home   Activity      [FAB]      Profile
                    // No, let's stick to:
                    // Home           [FAB]           Activity     Profile
                    // To make it symmetrical, we might need a dummy item or just standard BottomNavigationBar and push FAB up?
                    // No, requested explicitly to use FAB.
                    // Let's do:
                    // Home   Activity   [FAB]   Profile    (Chat Removed)
                    // This is 3 items + FAB.
                    // To balance, maybe: Home, Activity (Left) -- Profile (Right)?
                    // Let's go with:
                    // Left: Home.
                    // Right: Activity, Profile.
                    // This is 1 vs 2.
                    // Let's just put them in a row with proper spacing and FAB in center, allowing the eye to adjust.
                    // [Home]   [Activity]   [FAB]   [Profile]
                  ],
                ),
              ),

              // Middle Gap for FAB
              const SizedBox(width: 60),

              // Right Side: Activity, Profile
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.history, Icons.history, 'Activity', 1),
                    _buildNavItem(
                      Icons.person_outline,
                      Icons.person,
                      'Profile',
                      2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scanner'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final facultyName = authState.user?.name ?? 'Dr. Sharma';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/300?img=11',
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHITE SHEEP',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    facultyName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.black87,
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weekly Overview Chart (Mock)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ATTENDANCE TRENDS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Weekly Overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '↗ +2.4%',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Mock Chart Visual
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: CustomPaint(painter: _MockChartPainter()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const ['M', 'T', 'W', 'T', 'F']
                      .map(
                        (day) => Text(
                          day,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAction(
                Icons.calendar_today,
                'Mark\nLeave',
                Colors.blue,
              ),
              GestureDetector(
                onTap: () => context.push('/event-scan'),
                child: _buildQuickAction(
                  Icons.qr_code_scanner,
                  'Event\nScan',
                  Colors.orange,
                  wrapInContainer: false,
                ),
              ),
              _buildQuickAction(Icons.star, 'Post\nGrades', Colors.purple),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EventsScreen()),
                  );
                },
                child: _buildQuickAction(
                  Icons.event_available,
                  'Events',
                  Colors.pink,
                  wrapInContainer: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRecentActivityCard(
            'Kalapati Gnana Sekhar',
            '24BFA33L12',
            'Scanned just now',
            AppColors.primary,
          ),
          _buildRecentActivityCard(
            'Riya Gupta',
            '24BFA33L15',
            'Reported: Dress Code',
            AppColors.error,
            isWarning: true,
          ),
          // Spacer for bottom nav
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color, {
    bool wrapInContainer = true,
  }) {
    final content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );

    if (wrapInContainer) return content;
    return content; // Actually we handle tap outside
  }

  Widget _buildRecentActivityCard(
    String title,
    String subtitle,
    String status,
    Color color, {
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(
              isWarning ? Icons.warning : Icons.check_circle,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.8,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.1,
      size.width,
      size.height * 0.3,
    );

    canvas.drawPath(path, paint);

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.red.withValues(alpha: 0.2), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
