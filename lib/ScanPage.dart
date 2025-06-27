import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ScanerPage.dart';
import 'loginpage.dart';
import 'ChecklistPage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> with WidgetsBindingObserver{
  Timer? _poller;
  final TextEditingController _rfidController = TextEditingController();
  String errorMsg = '';
  bool isLoading = false;
  int inspectedCount = 0;
  int pendingCount = 0;
  bool isSummaryLoading = true;
  List<Map<String, dynamic>> notifications = [];
  bool isNotifLoading = false;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    fetchInspectionSummary();
    fetchNotifications();
    WidgetsBinding.instance.addObserver(this);

    _poller = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) fetchNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    setState(() => isNotifLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phone') ?? '';
    print('Fetching notifications for user_id (phone): $userId');

    const String notifApiUrl = 'https://esheapp.in/GE/App/get_notifications.php';

    try {
      final response = await http.post(
        Uri.parse(notifApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'user_id': userId}),
      );

      print('API status: ${response.statusCode}');
      print('API body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['notifications'] is List) {
          // SAFEGUARD: Filter only unseen notifications, but backend should already do this
          final notifList = List<Map<String, dynamic>>.from(data['notifications'])
              .where((n) => n['is_seen'] == 0)
              .toList();

          setState(() {
            notifications = notifList;
            unreadCount = notifications.length;
          });
        } else {
          setState(() {
            notifications = [];
            unreadCount = 0;
          });
        }
      } else {
        setState(() {
          notifications = [];
          unreadCount = 0;
        });
      }
    } catch (e) {
      setState(() {
        notifications = [];
        unreadCount = 0;
      });
      print('Error fetching notifications: $e');
    }
    if (mounted) setState(() => isNotifLoading = false);
  }


  Future<void> sendNotificationReply(int notifId, String reply) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phone') ?? ''; // Use 'phone' as the key

    const String replyApiUrl = 'https://esheapp.in/GE/App/reply_to_notification.php';

    try {
      await http.post(
        Uri.parse(replyApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'notification_id': notifId,
          'reply_text': reply,
          'user_id': userId, // This is the phone number now
        }),
      );
    } catch (e) {
      // handle error if you want
      print('Error sending notification reply: $e');
    }
  }

  void handleNotificationTap(Map<String, dynamic> notif) async {
    // You may want to call a backend API here to mark as seen
    setState(() {
      notifications.removeWhere((n) => n['id'] == notif['id']);
      unreadCount = notifications.where((n) => n['is_seen'] == 0).length;
    });
  }

  Future<Map<String, dynamic>?> markNotificationAsSeen(int notifId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phone') ?? '';
    const String api = 'https://esheapp.in/GE/App/mark_notification_seen.php';
    try {
      final response = await http.post(
        Uri.parse(api),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'notification_id': notifId, 'user_id': userId}),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        print('API response: $data'); // You can remove or replace this with UI code
        return data;
      } else {
        print('API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error marking notification as seen: $e');
      return null;
    }
  }

  Future<void> fetchInspectionSummary() async {
    setState(() => isSummaryLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name') ?? '';

    const String apiUrl = 'https://esheapp.in/GE/App/get_operator_equipments_status.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'operator_name': fullName}),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['equipments'] is List) {
          final eqs = List<Map<String, dynamic>>.from(data['equipments']);
          inspectedCount = eqs
              .where((e) => e['is_inspected'] == true)
              .length;
          pendingCount = eqs.length - inspectedCount;
        }
      }
    } catch (_) {}
    setState(() => isSummaryLoading = false);
  }

  Future<void> _goToChecklistPage() async {
    final rfid = _rfidController.text.trim();
    if (rfid.isEmpty) {
      setState(() {
        errorMsg = "Please enter or scan the RFID number.";
      });
      return;
    }
    setState(() {
      errorMsg = '';
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name') ?? '';
    const String apiUrl = 'https://esheapp.in/GE/App/get_equipment_by_rfid_and_user.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'rfid_no': rfid,
          'full_name': fullName,
          'role': "operator",
        }),
      );

      print('API response: ${response.body}');

      if (response.statusCode != 200 || response.body.isEmpty) {
        setState(() {
          isLoading = false;
          errorMsg = "Server error. Please try again.";
        });
        return;
      }

      final data = jsonDecode(response.body);

      if (data == null || !(data is Map)) {
        setState(() {
          isLoading = false;
          errorMsg = "Invalid response from server.";
        });
        return;
      }

      if (data['success'] == true &&
          data['equipments'] != null &&
          data['equipments'] is List &&
          data['equipments'].isNotEmpty) {
        final eq = data['equipments'][0];
        setState(() => isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChecklistPage(
                  operatorName: fullName,
                  rfidNo: eq['rfid_no'],
                  itemCategory: eq['item_category'],
                  description: eq['description'] ?? '', // Pass description!
                ),
          ),
        );
      } else {
        setState(() {
          isLoading = false;
          errorMsg =
              data['message'] ?? "Not authorized or equipment not found!";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AuthPage()),
                    (route) => false,
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Color(0xFFFFFF00)),
                tooltip: 'Notifications',
                onPressed: isNotifLoading
                    ? null
                    : () async {
                  await fetchNotifications(); // always get latest!
                  showNotificationDialog(context);
                },
              ),

              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],

        title: const Text(
          "Operator",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .30,
              child: Image.asset(
                'assets/GE_logo.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- INSPECTED / PENDING SUMMARY CARD ---
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 16),
                      child: isSummaryLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$inspectedCount',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Inspected",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Container(
                              width: 1.4, height: 38, color: Colors.teal[100]),
                          Column(
                            children: [
                              Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Pending",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- USER HEADER ---
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     CircleAvatar(
                  //       radius: 26,
                  //       backgroundColor: const Color(0xFFC0FF33),
                  //       child: const Icon(
                  //           Icons.person, color: Color(0xFF009688), size: 34),
                  //     ),
                  //     const SizedBox(width: 15),
                  //     const Text(
                  //       "Welcome, Operator!",
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 22,
                  //         fontWeight: FontWeight.bold,
                  //         letterSpacing: 0.5,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 30),

                  // RFID Input Field with QR Code Icon
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFFC0FF33), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _rfidController,
                      keyboardType: TextInputType.text,
                      maxLength: 20,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Enter RFID number',
                        counterText: '',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const Scanerpage()),
                            );
                            if (result != null && result is String) {
                              setState(() {
                                _rfidController.text = result;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  if (errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        errorMsg,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  const SizedBox(height: 12),

                  // Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _goToChecklistPage,
                      icon: const Icon(Icons.search),
                      label: const Text("Enter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Instructions Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 26, horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Color(0xFFC0FF33), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF00695C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          color: Colors.grey[300],
                          thickness: 1.0,
                          height: 1.0,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '1. Type a 10-digit RFID number or tap the QR icon to scan.\n\n'
                              '2. Ensure your RFID Reader or camera is active.\n\n'
                              '3. Hold the scanner over the RFID tag until it beeps or shows a result.\n\n'
                              '4. If no tag is detected, enter the RFID manually.\n\n'
                              '5. Proceed by pressing the Scan button to continue.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 17,
                            height: 1.62,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 34),

                  // Help Button
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFC0FF33),
                            width: 1.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 11),
                        elevation: 2,
                      ),
                      icon: const Icon(
                          Icons.help_outline_rounded, color: Color(0xFF009688),
                          size: 22),
                      label: const Text(
                        "Need Help?",
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        // TODO: Show help or support
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  void showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Notifications"),
              content: SizedBox(
                width: double.maxFinite,
                child: notifications.isEmpty
                    ? const Text('No notifications.')
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return Dismissible(
                      key: Key(notif['id'].toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        setState(() {
                          notifications.removeAt(index);
                          unreadCount = notifications.where((n) => n['is_seen'] == 0).length;
                        });
                        setDialogState(() {}); // If using StatefulBuilder in dialog
                        await markNotificationAsSeen(notif['id']);
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        title: Text(notif['title'] ?? ''),
                        subtitle: Text(notif['body'] ?? ''),
                        trailing: notif['is_seen'] == 0
                            ? const Icon(Icons.markunread, color: Colors.red)
                            : null,
                        onTap: () async {
                          Navigator.of(context).pop(); // Close dialog
                          await showReplyDialog(context, notif);
                          await fetchNotifications(); // This also updates count if you call setState inside fetchNotifications
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> showReplyDialog(BuildContext context, Map<String, dynamic> notif) async {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reply to: ${notif['title']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notif['body'] ?? ''),
              const SizedBox(height: 10),
              TextField(
                controller: replyController,
                decoration: const InputDecoration(hintText: 'Type your reply...'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reply = replyController.text.trim();
                if (reply.isNotEmpty) {
                  await sendNotificationReply(notif['id'], reply);
                  Navigator.of(context).pop();
                  handleNotificationTap(notif); // <-- Move here to remove after reply!
                }
              },

              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }
}
