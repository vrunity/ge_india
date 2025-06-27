import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'loginpage.dart';
import 'defect_action_page.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});
  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> with WidgetsBindingObserver {
  Timer? _poller;
  String errorMsg = '';
  bool isLoading = false;
  bool isDueToday = false;
  List<Map<String, dynamic>> equipments = [];
  List<Map<String, dynamic>> notifications = [];
  bool isNotifLoading = false;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkIfDueToday();
    _fetchSupervisorEquipments();
    fetchNotifications();
    _poller = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _fetchSupervisorEquipments();
    });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchSupervisorEquipments();
    }
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
  Future<void> _checkIfDueToday() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('category') ?? '';
      final due = await isInspectionDueToday(role);
      setState(() {
        isDueToday = due;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error in _checkIfDueToday: $e');
    }
  }

  Future<void> _fetchSupervisorEquipments() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final supervisorName = prefs.getString('full_name') ?? '';

    const String apiUrl = 'https://esheapp.in/GE/App/get_supervisor_equipment.php';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'supervisor_name': supervisorName}),
      );

      print('🛰️ fetchSupervisorEquipments → status ${response.statusCode}');
      print('🛰️ fetchSupervisorEquipments → body   ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['equipments'] != null) {
          equipments = List<Map<String, dynamic>>.from(data['equipments']);
        } else {
          equipments = [];
        }
      } else {
        equipments = [];
      }
    } catch (e) {
      print('⚠️ fetchSupervisorEquipments network error: $e');
      equipments = [];
    }

    // Augment each equipment with lock-until info (from next due date)
    for (var eq in equipments) {
      final rfid = eq['rfid_no'] as String? ?? '';
      final cat = eq['item_category'] as String? ?? '';
      final key = 'lock_until_${rfid}_$cat';

      if (prefs.containsKey(key)) {
        final stored = prefs.getString(key);
        DateTime? until = stored != null ? DateTime.tryParse(stored) : null;
        if (until != null && DateTime.now().isBefore(until)) {
          eq['disable_until'] = until.toIso8601String();
        } else {
          await prefs.remove(key);
          eq.remove('disable_until');
        }
      } else {
        eq.remove('disable_until');
      }

      print('🗓️ $rfid disable_until → ${eq['disable_until']}');
    }

    setState(() => isLoading = false);
  }

  Future<void> setCheckedOk(String rfidNo, String itemCategory) async {
    final prefs = await SharedPreferences.getInstance();
    final supervisorName = prefs.getString('full_name') ?? '';
    final role = prefs.getString('category') ?? '';

    const String apiUrl = 'https://esheapp.in/GE/App/set_supervisor_checked.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'rfid_no': rfidNo,
          'item_category': itemCategory,
          'supervisor_name': supervisorName,
        }),
      );

      print('🛰️ setCheckedOk → status ${response.statusCode}');
      print('🛰️ setCheckedOk → body   ${response.body}');

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Find next due date and lock until then
        final nextDueDate = await getNextDueDate(role);
        if (nextDueDate != null) {
          final key = 'lock_until_${rfidNo}_$itemCategory';
          await prefs.setString(key, nextDueDate.toIso8601String());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Checked OK—locked until next due day!"),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchSupervisorEquipments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${data['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('⚠️ setCheckedOk error → $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> isInspectionDueToday(String role) async {
    const String apiUrl = 'https://esheapp.in/GE/App/is_inspection_due_today.php';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {'role': role},
    );

    print('API Response: ${response.body}'); // 👈 Print the full API response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['is_due_today'] == true) {
        return true;
      }
    }
    return false;
  }

  Future<DateTime?> getNextDueDate(String role) async {
    const String apiUrl = 'https://esheapp.in/GE/App/is_inspection_due_today.php';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {'role': role},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final dueDates = List<String>.from(data['due_dates'] ?? []);
      final month = DateTime.now().month;
      final year = DateTime.now().year;
      final today = DateTime.now().day;

      // Get next due date in this month
      final dueDayInts = dueDates.map((d) => int.tryParse(d) ?? -1).where((d) => d > today).toList();
      dueDayInts.sort();
      if (dueDayInts.isNotEmpty) {
        return DateTime(year, month, dueDayInts.first);
      }
      // If no more due days this month, pick first in next month (simple logic)
      if (dueDates.isNotEmpty) {
        final firstNext = int.tryParse(dueDates.first) ?? 1;
        int nextMonth = month == 12 ? 1 : month + 1;
        int nextYear = month == 12 ? year + 1 : year;
        return DateTime(nextYear, nextMonth, firstNext);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Supervisor",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () async {
                // Clear session, then fully replace navigation stack with LoginPage
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => AuthPage()),
                      (route) => false,
                );
              }
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : equipments.isEmpty
          ? const Center(
        child: Text(
          "No data found.",
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        itemCount: equipments.length,
        itemBuilder: (context, index) {
          final eq = equipments[index];

          // Operator statuses
          Map<String, dynamic> operatorStatuses = {};
          if (eq['operator_statuses'] is Map) {
            operatorStatuses =
            Map<String, dynamic>.from(eq['operator_statuses'] as Map);
          }

          // Week/day info
          final todayStr = eq['today_date'] as String? ?? '';
          final weekdays =
          List<String>.from(eq['weekdays'] ?? ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
          final todayDate = DateTime.tryParse(todayStr) ?? DateTime.now();
          final todayIndex = todayDate.weekday - 1;

          final inspections = List<bool>.from(
              (eq['inspections'] as List<dynamic>?) ?? List.filled(7, false));

          // Lockout info (disable_until = last-pressed + next due day)
          DateTime? unlockDate;
          final bool isLocked = eq['disable_until'] != null &&
              DateTime.now().isBefore(DateTime.parse(eq['disable_until']));
          if (isLocked) {
            unlockDate = DateTime.parse(eq['disable_until']);
          }

          // Button logic: is today a due day?
          final dueDates = List<String>.from(eq['due_dates'] ?? []);
          final todayDay = todayDate.day;
          final isDueToday = dueDates.contains(todayDay.toString());

          // --- This logic: ---
          // If locked => disable always
          // If not locked && dueDates non-empty => enable (even if past due, until pressed)
          // If not locked && dueDates empty     => disable

          final canPress = !isLocked && dueDates.isNotEmpty;

          final defects = eq['defects_week'] as int? ?? 0;
          final btnLabel = isLocked && unlockDate != null
              ? "Checked until ${unlockDate.toLocal().toString().split(' ').first}"
              : "Checked OK";

          return Container(
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Info & controls
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + RFID
                        Row(
                          children: [
                            Text(
                              eq['item_category']?.toString().toUpperCase() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.circle,
                                color: Colors.green.shade400,
                                size: 8),
                            const SizedBox(width: 6),
                            Text(
                              eq['rfid_no'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),

                        // --- DESCRIPTION LINE ---
                        if ((eq['description'] as String?)?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 17, color: Colors.teal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    eq['description'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Operators pills
                        if (operatorStatuses.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Operators',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: operatorStatuses.entries.map((entry) {
                              final name = entry.key;
                              final insp = entry.value as bool;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: insp
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: insp
                                        ? Colors.green.shade500
                                        : Colors.red.shade400,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      insp
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 13,
                                      color: insp ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // This Week bar
                        const SizedBox(height: 16),
                        Text('This Week',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(7, (dayIndex) {
                            final isFuture = dayIndex > todayIndex;
                            final didInspect = inspections[dayIndex];

                            // choose background:
                            final bg = isFuture
                                ? Colors.grey.shade200
                                : (didInspect
                                ? Colors.green.shade300
                                : Colors.red.shade300);

                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                weekdays[dayIndex],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          }),
                        ),

                        // Checked OK button
                        const SizedBox(height: 16),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              icon: Icon(isLocked ? Icons.lock : Icons.check, color: Colors.white),
                              label: Text(btnLabel, style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canPress
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                                elevation: canPress ? 3 : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                shadowColor: Colors.black12,
                              ),
                              onPressed: canPress
                                  ? () async {
                                await setCheckedOk(eq['rfid_no']!, eq['item_category']!);
                                setState(() {}); // to refresh lock status
                              }
                                  : null,
                            )
                        ),
                      ],
                    ),
                  ),

                  // RIGHT: Defects box (now tappable)
                  GestureDetector(
                    onTap: () {
                      if (defects == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No defects to show'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DefectActionPage(
                              rfidNo: eq['rfid_no'] as String,
                              itemCategory: eq['item_category'] as String,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(left: 8, right: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.shade100, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            defects.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Color(0xFF009688),
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            "Defects",
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
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
