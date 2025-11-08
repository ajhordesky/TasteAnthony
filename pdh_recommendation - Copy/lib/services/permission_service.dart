import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> checkLocationPermission() async {
    try {
      // Check if location services are enabled
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        return false;
      }

      // Check location permissions
      final status = await Permission.locationWhenInUse.status;
      
      if (status.isDenied) {
        // Request permission
        final result = await Permission.locationWhenInUse.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print("❌ Error checking location permission: $e");
      return false;
    }
  }

  // NEW: Check notification permission
  Future<bool> checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      
      if (status.isDenied) {
        print("🔔 Notification permission denied, requesting...");
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        print("🔔 Notification permission permanently denied");
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print("❌ Error checking notification permission: $e");
      return false;
    }
  }

  Future<bool> checkBackgroundLocationPermission() async {
    try {
      // First check foreground permission
      final foregroundGranted = await checkLocationPermission();
      if (!foregroundGranted) return false;

      // Check background permission (Android 10+)
      final backgroundStatus = await Permission.locationAlways.status;
      
      if (backgroundStatus.isDenied) {
        final result = await Permission.locationAlways.request();
        return result.isGranted;
      }
      
      if (backgroundStatus.isPermanentlyDenied) {
        return false;
      }

      return backgroundStatus.isGranted;
    } catch (e) {
      print("❌ Error checking background location permission: $e");
      return false;
    }
  }

  // NEW: Combined method to request all necessary permissions
  Future<Map<String, bool>> requestAllPermissions() async {
    print("🔍 Requesting all necessary permissions...");
    
    final Map<String, bool> results = {};
    
    try {
      // Request location permission first
      final locationGranted = await ensureLocationPermission();
      results['location'] = locationGranted;
      
      // Request notification permission
      final notificationGranted = await checkNotificationPermission();
      results['notification'] = notificationGranted;
      
      // Optionally request background location if foreground is granted
      if (locationGranted) {
        final backgroundGranted = await checkBackgroundLocationPermission();
        results['backgroundLocation'] = backgroundGranted;
      } else {
        results['backgroundLocation'] = false;
      }
      
      print("📊 Permission results: $results");
      return results;
      
    } catch (e) {
      print("❌ Error requesting all permissions: $e");
      return {
        'location': false,
        'notification': false,
        'backgroundLocation': false,
      };
    }
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    return await Geolocator.getLocationAccuracy();
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Additional method to check and request permissions in one call
  Future<bool> ensureLocationPermission() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (hasPermission) return true;

      // If not granted, request it
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    } catch (e) {
      print("❌ Error ensuring location permission: $e");
      return false;
    }
  }
}