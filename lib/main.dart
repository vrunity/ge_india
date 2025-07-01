import 'package:flutter/material.dart';
import 'package:ge_india/root_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Local notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Channel for Android notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'main_channel',
  'Main Notifications',
  description: 'GE Vernova notifications',
  importance: Importance.max,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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

// Send FCM token + userId to your server
Future<void> sendFcmTokenToServer() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('phone') ?? '';

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  if (userId.isNotEmpty && fcmToken != null && fcmToken.isNotEmpty) {
    final url = Uri.parse("https://esheapp.in/GE/App/send_fcm.php");
    final response = await http.post(
      url,
      body: {
        'user_id': userId,
        'fcm_token': fcmToken,
      },
    );
    print('Token send response: ${response.body}');
  } else {
    print('User ID or FCM Token missing');
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

    // iOS permissions (optional, for Android mostly ignored)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Print FCM token for testing
    String? token = await messaging.getToken();
    print("FCM Token: $token");

    // Send FCM token and userId to server
    await sendFcmTokenToServer();

    // Handle token refresh: always update server if FCM token changes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await sendFcmTokenToServer();
    });

    // Foreground notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("onMessage: Received FCM message");
      print("onMessage: Message data: ${message.data}");
      if (message.notification != null) {
        print('onMessage: Message also contained a notification:');
        print('onMessage: title: ${message.notification!.title}');
        print('onMessage: body: ${message.notification!.body}');
      }
      _showLocalNotification(message);
    });

    // When notification is tapped and app is open/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('onMessageOpenedApp: Message data: ${message.data}');
      final String? notificationId = message.data['notification_id'];
      debugPrint('Notification tapped. ID: $notificationId');
    });

    // App opened from terminated state via notification tap
    final RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('getInitialMessage: Message data: ${initialMessage.data}');
      final String? notificationId = initialMessage.data['notification_id'];
      debugPrint('Launched from notification. ID: $notificationId');
    }
  }

// Background FCM handler (already top-level!)
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print('Background FCM message: ${message.data}');
    _showLocalNotification(message);
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
