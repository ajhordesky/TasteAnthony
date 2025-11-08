import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh_recommendation/screens/login_screen.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _performFullLogout(BuildContext context) async {
    try {
      print('Logging out...');
      
      // Stop geofence monitoring
      final geofenceService = Provider.of<GeofenceService>(context, listen: false);
      await geofenceService.stopGeofencing();
      
      // Firebase sign out
      await FirebaseAuth.instance.signOut();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('Prefs Cleared');

      // Navigate to login screen and clear all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );

      print('Logged out successfully!');
    } catch (e) {
      print('❌ Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ExpansionTile(
                    title: Text(
                      'Application Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      ExpansionTile(title: Text('Version History')),
                      ExpansionTile(title: Text('Permissions')),
                    ],
                  ),
                  ExpansionTile(
                    title: Text(
                      'Manage Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      ExpansionTile(title: Text('Flagged Reviews')),
                      ExpansionTile(title: Text('Resolved Issues')),
                      ExpansionTile(title: Text('All Reviews')),
                    ],
                  ),
                  ExpansionTile(
                    title: Text(
                      'Report A Problem',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      ExpansionTile(title: Text('Report A Bug')),
                      ExpansionTile(title: Text('Request A Feature')),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _performFullLogout(context),
                      child: Text('Log Out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
