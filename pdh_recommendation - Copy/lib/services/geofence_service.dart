import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceEvent {
  final String identifier;
  final String action; // ENTER, EXIT
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GeofenceEvent({
    required this.identifier,
    required this.action,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'GeofenceEvent{identifier: $identifier, action: $action, lat: $latitude, lng: $longitude}';
  }
}

class GeofenceService {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  final PermissionService permissionService;
  final NotificationService notificationService;
  final SharedPreferences? prefs;
  
  final StreamController<GeofenceEvent> _geofenceEventController =
      StreamController<GeofenceEvent>.broadcast();
  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  final List<GeofenceRegion> _geofences = [];
  
  // Track active visit timers
  final Map<String, Timer> _visitTimers = {};
  
  // Default geofence coordinates (Googleplex)
  final double _defaultLatitude = 28.062303;
  final double _defaultLongitude = -80.622242;
  final double _defaultRadius = 10.0;

  Stream<GeofenceEvent> get onGeofenceEvent => _geofenceEventController.stream;
  Stream<Position> get onLocationUpdate => _locationController.stream;

  GeofenceService({
    required this.permissionService,
    required this.notificationService,
    this.prefs,
  });

  static void initializeWorkmanager() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      print("Background task executed: $taskName");
      
      try {
        switch (taskName) {
          case 'geofenceMonitoringTask':
            await _checkGeofencesInBackground();
          case 'periodicLocationTask':
            await _getPeriodicLocationUpdate();
        }
        return Future.value(true);
      } catch (e) {
        print("Background task error: $e");
        return Future.value(false);
      }
    });
  }

  static Future<void> _checkGeofencesInBackground() async {
    // This would check geofences in background
    // Implementation depends on how you want to store/access geofences
    print("Checking geofences in background");
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("Background geofence check at: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error in background geofence check: $e");
    }
  }

  static Future<void> _getPeriodicLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      print("Background location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error getting background location: $e");
    }
  }

  Future<bool> initialize() async {
    try {
      // Initialize workmanager for background tasks
      initializeWorkmanager();
      
      // Load saved geofences
      await _loadGeofences();
      
      print("✅ GeofenceService initialized");
      return true;
    } catch (e) {
      print("❌ Failed to initialize GeofenceService: $e");
      return false;
    }
  }

  Future<void> _loadGeofences() async {
    if (prefs == null) return;
    
    final geofencesJson = prefs!.getStringList('geofences');
    if (geofencesJson != null) {
      for (final json in geofencesJson) {
        try {
          final map = jsonDecode(json);
          _geofences.add(GeofenceRegion(
            identifier: map['identifier'],
            latitude: map['latitude'],
            longitude: map['longitude'],
            radius: map['radius'],
            isInside: map['isInside'] ?? false,
          ));
          print("📍 Loaded geofence: ${map['identifier']}");
        } catch (e) {
          print("❌ Error loading geofence: $e");
        }
      }
    }
  }

  Future<void> _saveGeofences() async {
    if (prefs == null) return;
    
    final geofencesJson = _geofences.map((geofence) {
      return jsonEncode({
        'identifier': geofence.identifier,
        'latitude': geofence.latitude,
        'longitude': geofence.longitude,
        'radius': geofence.radius,
        'isInside': geofence.isInside,
      });
    }).toList();
    
    await prefs!.setStringList('geofences', geofencesJson);
  }

  Future<bool> startGeofencing() async {
    if (_isMonitoring) return true;

    try {
      // Check permissions
      final hasPermission = await permissionService.checkLocationPermission();
      if (!hasPermission) {
        print("❌ Location permission not granted");
        return false;
      }

      // Add default geofence if none exist
      if (_geofences.isEmpty) {
        await addGeofence(
          identifier: 'target_location',
          latitude: _defaultLatitude,
          longitude: _defaultLongitude,
          radius: _defaultRadius,
        );
      }

      // Start periodic monitoring
      _startPeriodicMonitoring();

      // Register background task
      await Workmanager().registerPeriodicTask(
        "geofence_monitoring",
        "geofenceMonitoringTask",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      _isMonitoring = true;
      print("✅ Geofence monitoring started");
      return true;
    } catch (e) {
      print("❌ Failed to start geofencing: $e");
      return false;
    }
  }

  Future<void> stopGeofencing() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    // Cancel all active visit timers
    _cancelAllVisitTimers();
    
    await Workmanager().cancelByUniqueName("geofence_monitoring");
    _isMonitoring = false;
    
    print("🛑 Geofence monitoring stopped");
  }

  void _startPeriodicMonitoring() {
    // Check geofences every 30 seconds when app is in foreground
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkGeofences();
    });
  }

  Future<void> _checkGeofences() async {
    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _locationController.add(currentPosition);

      for (final geofence in _geofences) {
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          geofence.latitude,
          geofence.longitude,
        );

        final wasInside = geofence.isInside;
        final isInside = distance <= geofence.radius;

        if (isInside && !wasInside) {
          // Entered geofence
          _triggerGeofenceEvent(geofence, 'ENTER', currentPosition);
          geofence.isInside = true;
        } else if (!isInside && wasInside) {
          // Exited geofence
          _triggerGeofenceEvent(geofence, 'EXIT', currentPosition);
          geofence.isInside = false;
        }
      }
      
      // Save geofence states
      await _saveGeofences();
    } catch (e) {
      print("❌ Error checking geofences: $e");
    }
  }

  Future<void> _triggerGeofenceEvent(GeofenceRegion geofence, String action, Position position) async {
    final event = GeofenceEvent(
      identifier: geofence.identifier,
      action: action,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
    );

    if (action == 'ENTER') {
      // Record entrance time in Firestore
      await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'entrance': event.timestamp,
            }, SetOptions(merge: true));

      // Start timer for halfway notification
      _startHalfwayNotificationTimer(geofence.identifier, event.timestamp);

      // _geofenceEventController.add(event);
      _handleGeofenceNotification(event);
    
      print('🎯 Geofence Event: ${geofence.identifier} $action');
    } else if (action == 'EXIT') {
      // Cancel the halfway notification timer for this visit
      _cancelVisitTimer(geofence.identifier);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Calculate new average
      int lastAverage = userData['average_duration_at_pdh'];
      int totalVisits = userData['num_visits'];
      int newVisitDuration = event.timestamp.difference((userData['entrance'] as Timestamp).toDate()).inSeconds;

      int newAverage = (((lastAverage * (totalVisits)) + newVisitDuration) / (totalVisits + 1)).round();

      await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'average_duration_at_pdh': newAverage,
              'num_visits': FieldValue.increment(1),
            }, SetOptions(merge: true));

    }
  }

  void _startHalfwayNotificationTimer(String geofenceIdentifier, DateTime entranceTime) {
    // Get user's average visit duration from Firestore
    _getAverageVisitDuration().then((averageDuration) {
      if (averageDuration > 0) {
        // Calculate halfway point (in seconds)
        int halfwayPoint = (averageDuration ~/ 2);
        
        if (halfwayPoint > 0) {
          // Create timer that will trigger at halfway point
          Timer timer = Timer(Duration(seconds: halfwayPoint), () {
            _sendHalfwayNotification(geofenceIdentifier);
            // Remove timer from tracking since it's completed
            _visitTimers.remove(geofenceIdentifier);
          });
          
          // Store the timer so we can cancel it if user exits early
          _visitTimers[geofenceIdentifier] = timer;
          
          print("⏰ Halfway notification scheduled for $halfwayPoint seconds from now");
        }
      }
    });
  }

  Future<int> _getAverageVisitDuration() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['average_duration_at_pdh'] ?? 0;
      }
      return 0;
    } catch (e) {
      print("❌ Error getting average visit duration: $e");
      return 0;
    }
  }

  void _sendHalfwayNotification(String geofenceIdentifier) {
    String title = "Tasteful Panthers";
    String message = "You're halfway through your visit! How's your meal so far?";
    
    notificationService.showNotification(title, message);
    print("🔔 Halfway notification sent for $geofenceIdentifier");
  }

  void _cancelVisitTimer(String geofenceIdentifier) {
    Timer? timer = _visitTimers[geofenceIdentifier];
    if (timer != null) {
      timer.cancel();
      _visitTimers.remove(geofenceIdentifier);
      print("⏹️ Cancelled halfway timer for $geofenceIdentifier");
    }
  }

  void _cancelAllVisitTimers() {
    _visitTimers.forEach((identifier, timer) {
      timer.cancel();
    });
    _visitTimers.clear();
    print("⏹️ All visit timers cancelled");
  }

  Future<void> addGeofence({
    required String identifier,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    _geofences.add(GeofenceRegion(
      identifier: identifier,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    ));

    await _saveGeofences();
    print("📍 Geofence added: $identifier ($latitude, $longitude) radius: ${radius}m");
  }

  Future<void> removeGeofence(String identifier) async {
    _geofences.removeWhere((geofence) => geofence.identifier == identifier);
    await _saveGeofences();
    print("🗑️ Geofence removed: $identifier");
  }

  List<GeofenceRegion> getGeofences() {
    return List.from(_geofences);
  }

  void _handleGeofenceNotification(GeofenceEvent event) {
    String title = "Tasteful Panthers";
    String message = "";
    switch (event.action) {
      case 'ENTER':
        message = "Tap to taste a hand picked meal for you!";
      default:
        message = "Geofence event: ${event.action} for ${event.identifier}";
    }

    notificationService.showNotification(title, message);
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("❌ Failed to get current location: $e");
      return null;
    }
  }

  bool get isMonitoring => _isMonitoring;

  void dispose() {
    _monitoringTimer?.cancel();
    _cancelAllVisitTimers();
    _geofenceEventController.close();
    _locationController.close();
    stopGeofencing();
  }
}

class GeofenceRegion {
  final String identifier;
  final double latitude;
  final double longitude;
  final double radius;
  bool isInside;

  GeofenceRegion({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isInside = false,
  });
}