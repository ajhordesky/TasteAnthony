import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdh_recommendation/screens/home_screen.dart';
import 'package:pdh_recommendation/screens/review_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart' as notif_service;
import 'package:pdh_recommendation/services/permission_service.dart' as perm_service;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();
  final permissionService = perm_service.PermissionService();
  final notificationService = notif_service.NotificationService();
  notificationService.navigatorKey = navigatorKey;
  final geofenceService = GeofenceService(
    permissionService: permissionService,
    notificationService: notificationService,
    prefs: sharedPreferences,
  );
  
  await geofenceService.initialize();
  await notificationService.initialize();
  
  // Request ALL permissions on app start (location + notifications)
  await _requestAllPermissions(permissionService);
  
  runApp(MyApp(
    geofenceService: geofenceService,
    permissionService: permissionService,
    notificationService: notificationService,
  ));
}

// REPLACE the existing _requestLocationPermissions function with this:
Future<void> _requestAllPermissions(perm_service.PermissionService permissionService) async {
  try {
    print("🔍 Checking and requesting all permissions on app start...");
    
    // Request all permissions and get results
    final permissionResults = await permissionService.requestAllPermissions();
    
    // Log the results
    if (permissionResults['location'] == true) {
      print("✅ Location permission granted");
    } else {
      print("❌ Location permission denied");
    }
    
    if (permissionResults['notification'] == true) {
      print("✅ Notification permission granted");
    } else {
      print("❌ Notification permission denied");
    }
    
    if (permissionResults['backgroundLocation'] == true) {
      print("✅ Background location permission granted");
    } else {
      print("ℹ️ Background location permission not granted");
    }
    
  } catch (e) {
    print("❌ Error requesting permissions: $e");
  }
}

class MyApp extends StatelessWidget {
  final GeofenceService geofenceService;
  final perm_service.PermissionService permissionService;
  final notif_service.NotificationService notificationService;
  
  MyApp({
    super.key, 
    required this.geofenceService,
    required this.permissionService,
    required this.notificationService,
  });
  
  final Color fitCrimson = const Color.fromARGB(255, 119, 0, 0);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MyAppState()),
        Provider<GeofenceService>(create: (_) => geofenceService),
        Provider<perm_service.PermissionService>(create: (_) => permissionService),
        Provider<notif_service.NotificationService>(create: (_) => notificationService),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'PDH Recommendation',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: fitCrimson,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => HomePage(),
          '/review': (context) => ReviewPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    // Don't use Provider here - context isn't ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundServices();
    });
  }

  void _startBackgroundServices() {
    // Now context is available after first frame
    final geofenceService = Provider.of<GeofenceService>(context, listen: false);
    final permissionService = Provider.of<perm_service.PermissionService>(context, listen: false);
    
    _checkAndStartGeofencing(geofenceService, permissionService);
    
    // Your existing listeners...
    geofenceService.onGeofenceEvent.listen((event) {
      print('🎯 Geofence Event: ${event.identifier} ${event.action}');
      
      final notificationService = Provider.of<notif_service.NotificationService>(context, listen: false);
      notificationService.showNotification(
        'Geofence ${event.action}',
        'You ${event.action.toLowerCase()}ed ${event.identifier}',
      );
    });

    geofenceService.onLocationUpdate.listen((position) {
      print('📍 Location Update: ${position.latitude}, ${position.longitude}');
    });
  }

  Future<void> _checkAndStartGeofencing(
    GeofenceService geofenceService, 
    perm_service.PermissionService permissionService
  ) async {
    if (_isCheckingPermissions) return;
    
    _isCheckingPermissions = true;
    
    try {
      // Check if we have location permissions
      final hasPermission = await permissionService.checkLocationPermission();
      
      if (hasPermission && !geofenceService.isMonitoring) {
        print("🚀 Auto-starting geofencing service...");
        final success = await geofenceService.startGeofencing();
        
        if (success) {
          print("✅ Geofencing auto-started successfully");
        } else {
          print("❌ Failed to auto-start geofencing");
        }
      } else if (!hasPermission) {
        print("ℹ️ Location permission not available, waiting for user action");
      } else {
        print("✅ Geofencing already active");
      }
    } catch (e) {
      print("❌ Error checking/starting geofencing: $e");
    } finally {
      _isCheckingPermissions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return Scaffold(
              body: LoginPage(),
              backgroundColor: Theme.of(context).colorScheme.primary,
            );
          } else {
            // Use the updated NavigationController
            return NavigationController();
          }
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking authentication...'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// MyAppState remains unchanged and provides global database state.
class MyAppState extends ChangeNotifier {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<dynamic, dynamic>? _data;
  bool _isLoading = true;

  // track nav bar index
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // Getter for data
  Map<dynamic, dynamic>? get data => _data;

  // Getter for loading state
  bool get isLoading => _isLoading;

  MyAppState() {
    // Fetch data when state is initialized.
    fetchData();
  }

  Null get currentUser => null;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      DataSnapshot snapshot = await _database.get();
      if (snapshot.exists) {
        _data = snapshot.value as Map<dynamic, dynamic>;
      } else {
        print("No data available");
        _data = {};
      }
    } catch (e) {
      print("Error fetching data: $e");
      _data = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> writeData(String path, dynamic value) async {
    try {
      await _database.child(path).set(value);
      await fetchData();
    } catch (e) {
      print("Error writing data: $e");
    }
  }

  Future<void> updateData(String path, Map<String, dynamic> updates) async {
    try {
      await _database.child(path).update(updates);
      await fetchData();
    } catch (e) {
      print("Error updating data: $e");
    }
  }

  Future<void> deleteData(String path) async {
    try {
      await _database.child(path).remove();
      await fetchData();
    } catch (e) {
      print("Error deleting data: $e");
    }
  }
}