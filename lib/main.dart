import 'package:flutter/material.dart';
import 'package:ge_india/root_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Local notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Channel for Android notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'main_channel', // id
  'Main Notifications', // title
  description: 'GE Vernova notifications',
  importance: Importance.max,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Optionally show a local notification even in background
  _showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // You can parse payload here and navigate if needed
      debugPrint('Notification payload: ${response.payload}');
    },
  );

  // Create the channel (required for Android 13+)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

// Helper to show a local notification from RemoteMessage
void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['notification_id'] ?? '',
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // iOS permissions (important if you want iOS support)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Print FCM token for testing
    String? token = await messaging.getToken();
    print("FCM Token: $token");

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // When notification is tapped and app is open/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String? notificationId = message.data['notification_id'];
      // TODO: Navigate to detail/reply, or show dialog, etc.
      debugPrint('Notification tapped. ID: $notificationId');
    });

    // For handling app opened from terminated state via notification tap
    final RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String? notificationId = initialMessage.data['notification_id'];
      // TODO: Handle this case too
      debugPrint('Launched from notification. ID: $notificationId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GE Vernova',
      theme: ThemeData(
        primaryColor: const Color(0xFF00695C),
        scaffoldBackgroundColor: const Color(0xFF009688),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: const Color(0xFFC0FF33)),
      ),
      home: SplashPage(),
    );
  }
}
