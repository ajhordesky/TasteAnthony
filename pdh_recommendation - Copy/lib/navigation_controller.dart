import 'package:flutter/material.dart';
import 'package:pdh_recommendation/screens/search_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/bottom_nav_bar.dart';

// navigation_controller.dart
class NavigationController extends StatefulWidget {
  final int? initialIndex; // Allow external index control
  
  const NavigationController({super.key, this.initialIndex});
  
  @override
  State<NavigationController> createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SearchScreen(),
    DashboardPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Use initial index if provided
    _currentIndex = widget.initialIndex ?? 0;
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Public method to change tab externally
  void changeTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTapped,
      ),
    );
  }
}