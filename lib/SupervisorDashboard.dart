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
  bool isLoading = false;
  bool isDueToday = false;
  List<Map<String, dynamic>> equipments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkIfDueToday();
    _fetchSupervisorEquipments();

    _poller = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _fetchSupervisorEquipments();
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
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications, color: Color(0xFFFFFF00)),
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

          // parse operator statuses
          Map<String, dynamic> operatorStatuses = {};
          if (eq['operator_statuses'] is Map) {
            operatorStatuses =
            Map<String, dynamic>.from(eq['operator_statuses'] as Map);
          }
          final anyInspected =
          operatorStatuses.values.any((v) => v == true);

          // week/day info
          final todayStr = eq['today_date'] as String? ?? '';
          final weekdays = List<String>.from(
              eq['weekdays'] ?? ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
          final todayDate = DateTime.tryParse(todayStr) ?? DateTime.now();
          final todayIndex = todayDate.weekday - 1;

          final inspections = List<bool>.from(
              (eq['inspections'] as List<dynamic>?) ?? List.filled(7, false)
          );

          // local lockout
          DateTime? unlockDate;
          final bool isLocked = eq['disable_until'] != null &&
              DateTime.now().isBefore(DateTime.parse(eq['disable_until']));
          if (isLocked) {
            unlockDate = DateTime.parse(eq['disable_until']);
          }

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
                                backgroundColor: (isLocked || !isDueToday)
                                    ? Colors.grey.shade400
                                    : Colors.green.shade600,
                                elevation: isLocked ? 0 : 3,
                                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                shadowColor: Colors.black12,
                              ),
                              onPressed: (isLocked || !isDueToday)
                                  ? null
                                  : () => setCheckedOk(eq['rfid_no']!, eq['item_category']!),
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
      ),
    );
  }
}
