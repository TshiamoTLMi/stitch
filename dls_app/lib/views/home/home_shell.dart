import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../upload_screen.dart';
import '../wardrobe_dashboard.dart';
import 'dashboard_page.dart';
import 'event_planner_page.dart';
import 'outfit_generator_page.dart';
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _boundWardrobe = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final userId = user?.uid ?? 'guest';

    if (!_boundWardrobe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WardrobeController>().bindStream(userId);
      });
      _boundWardrobe = true;
    }

    final pages = [
      DashboardPage(userId: userId),
      const WardrobeDashboard(),
      OutfitGeneratorPage(userId: userId),
      EventPlannerPage(userId: userId),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Digital Lesela Sete',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none_rounded, color: AppTheme.onSurface),
          ),
        ],
      ),
      body: SafeArea(top: false, child: pages[_index]),
      floatingActionButton: _index == 1
          ? GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UploadScreen()),
              ),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Color(0xFF3C2F00), size: 28),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLow.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(40),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.surfaceHigh,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.checkroom), label: 'Closet'),
            NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Generate'),
            NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Events'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
