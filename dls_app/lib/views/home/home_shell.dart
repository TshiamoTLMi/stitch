import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';
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
  int _unreadCount = 0;
  List<EventModel> _upcomingEvents = [];

  void _updateEvents(List<EventModel> events) {
    if (!mounted) return;
    final currentReminderEvents = events.where((event) => NotificationService.isNextLocalDay(event.date)).toList();
    setState(() {
      _upcomingEvents = currentReminderEvents;
      _unreadCount = currentReminderEvents.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final userId = user.uid;

    if (!_boundWardrobe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WardrobeController>().initialize(userId);
        // Start listening to upcoming events so the bell badge stays fresh.
        context
            .read<EventService>()
            .streamUpcomingEvents(userId)
            .listen(_updateEvents);
        // Reschedule all notifications on fresh login.
        context
            .read<EventService>()
            .streamUpcomingEvents(userId)
            .first
            .then(NotificationService().rescheduleAllEvents);
      });
      _boundWardrobe = true;
    }

    final pages = [
      DashboardPage(
        userId: userId,
        onOpenGenerator: () => setState(() => _index = 2),
      ),
      WardrobeDashboard(userId: userId),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _openNotifPanel(context, userId),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB4A5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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

  void _openNotifPanel(BuildContext context, String userId) {
    setState(() => _unreadCount = 0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifPanel(
        events: _upcomingEvents,
        onGoToEvents: () {
          Navigator.of(context).pop();
          setState(() => _index = 3);
        },
      ),
    );
  }
}

// ── Notification bottom sheet ─────────────────────────────────────────────────

class _NotifPanel extends StatelessWidget {
  const _NotifPanel({required this.events, required this.onGoToEvents});

  final List<EventModel> events;
  final VoidCallback onGoToEvents;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B1B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── drag handle + header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4D4635),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Color(0xFFE5E2E1),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: onGoToEvents,
                        child: const Text(
                          'See all events',
                          style: TextStyle(
                            color: Color(0xFFF2CA50),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Browser notifications are unavailable or unverified. Upcoming events remain visible here in the app.',
                  style: TextStyle(color: Color(0xFFD0C5AF), fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            // ── list ─────────────────────────────────────────────────────
            Expanded(
              child: events.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 56, color: Color(0xFF353534)),
                          SizedBox(height: 12),
                          Text(
                            'No upcoming events',
                            style: TextStyle(
                              color: Color(0xFFD0C5AF),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add an event to get outfit reminders.',
                            style: TextStyle(
                              color: Color(0xFF99907C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: events.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF2A2A2A), height: 1),
                      itemBuilder: (_, i) => _NotifTile(event: events[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final daysAway = event.date.difference(DateTime.now()).inDays;
    final dateLabel = DateFormat('EEE, d MMM').format(event.date);
    final urgency = daysAway == 0
        ? 'Today!'
        : daysAway == 1
            ? 'Tomorrow'
            : 'In $daysAway days';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2CA50).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: Color(0xFFF2CA50), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    color: Color(0xFFE5E2E1),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateLabel · ${event.occasion}',
                  style: const TextStyle(
                    color: Color(0xFFD0C5AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: daysAway <= 1
                  ? const Color(0xFFFFB4A5).withValues(alpha: 0.15)
                  : const Color(0xFF96E400).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              urgency,
              style: TextStyle(
                color: daysAway <= 1
                    ? const Color(0xFFFFB4A5)
                    : const Color(0xFF96E400),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
