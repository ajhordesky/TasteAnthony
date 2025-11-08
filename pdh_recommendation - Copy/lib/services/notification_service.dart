import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/screens/review_screen.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Navigation key for handling redirects from notifications
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Internal type mapping
  static const int TYPE_DASH = 0;
  static const int TYPE_REVIEW = 1;
  static const int TYPE_NOTHING = 2;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _isInitialized = true;
    
    // Create notification channel for Android
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Notifications',
      description: 'Notifications when entering/exiting geofences',
      importance: Importance.high,
    );

    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  Future<void> showNotification(String title, String message) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Determine type based on title/message content
    int type = _determineTypeFromContent(title, message);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications when entering/exiting geofences',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      message,
      platformChannelSpecifics,
      payload: type.toString(), // Pass type as payload for redirection
    );
  }

  // Determine type based on notification content
  int _determineTypeFromContent(String title, String message) {
    // Logic to determine type based on your content
    if (title.toLowerCase().contains('tasteful') && 
        message.toLowerCase().contains('hand picked meal')) {
      return TYPE_DASH; // 0 - Redirect to home
    } else if (title.toLowerCase().contains('tasteful') && 
               message.toLowerCase().contains('halfway')) {
      return TYPE_REVIEW; // 1 - Redirect to review creation
    } else {
      return TYPE_NOTHING; // 2 - Do nothing
    }
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null) {
      final int type = int.tryParse(payload) ?? TYPE_NOTHING;
      _handleRedirection(type);
    }
  }

  void _handleRedirection(int type) {
    final currentState = navigatorKey.currentState;
    if (currentState == null) {
      print('❌ Navigator state not available');
      return;
    }

    print('🔄 Handling redirection for type: $type');
    
    switch (type) {
      case TYPE_DASH:
        print('🏠 Switching to home tab...');
        // Navigate to NavigationController with home tab
        currentState.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => NavigationController(initialIndex: 2)),
          (route) => false,
        );
        
      case TYPE_REVIEW:
        print('⭐ Showing ReviewPage as modal...');
        showModalBottomSheet(
          context: currentState.context,
          isScrollControlled: true, // Makes it nearly full-screen
          backgroundColor: Colors.transparent,
          builder: (context) => ReviewPage(),
        );
        
      default:
        print('➡️ No redirection needed');
    }
  }
}