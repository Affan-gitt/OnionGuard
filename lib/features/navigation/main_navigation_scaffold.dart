import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../dashboard/screens/home_dashboard_screen.dart';
import '../analytics/screens/analytics_screen.dart';
import '../controls/screens/controls_screen.dart';
import '../alerts/screens/alert_centre_screen.dart';
import '../settings/screens/settings_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomeDashboardScreen(),
    AnalyticsScreen(),
    ControlsScreen(),
    AlertCentreScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildGlassNavBar(context),
    );
  }

  Widget _buildGlassNavBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.deepForest.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: AppConstants.borderEmerald, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset > 0 ? bottomInset : 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                _buildNavItem(1, Icons.query_stats_rounded, 'Analytics'),
                _buildNavItem(2, Icons.tune_rounded, 'Controls'),
                _buildNavItem(3, Icons.notifications_active_rounded, 'Alerts'),
                _buildNavItem(4, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.emerald.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppConstants.emerald.withValues(alpha: 0.6), width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppConstants.emerald.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppConstants.emerald : AppConstants.mutedGreenGrey,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppConstants.cream : AppConstants.mutedGreenGrey,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
