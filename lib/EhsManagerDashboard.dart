import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'CategoryListPage.dart';
import 'loginpage.dart';

class EhsmanagerDashboard extends StatefulWidget {
  const EhsmanagerDashboard({super.key});

  @override
  State<EhsmanagerDashboard> createState() => _EhsmanagerDashboardState();
}

class _EhsmanagerDashboardState extends State<EhsmanagerDashboard> {
  List<dynamic> equipments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAreaManagerEquipments();
  }

  Future<void> fetchAreaManagerEquipments() async {
    final prefs = await SharedPreferences.getInstance();
    final areaManagerName = prefs.getString('full_name') ?? '';

    const String apiUrl = 'https://esheapp.in/GE/App/get_ehs_manager_equipment.php';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'ehs_manager_name': areaManagerName}),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      setState(() {
        equipments = data['equipments'];
        isLoading = false;
      });
    } else {
      setState(() {
        equipments = [];
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "EHS Manager", // <-- Your desired title here
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // Optional: centers the title
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // This logs out the user

              // Navigate to login page (replace with your login page widget)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.notifications, color: Color(0xFFFFFF00)),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: equipments.length,
        itemBuilder: (context, index) {
          final eq = equipments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 18.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq['item_category'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                          const SizedBox(height: 10),
                          const Text('Today\nInspection',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          Text(
                            '00\nout of 00', // You can update with real inspection data if available
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text('This Week', style: TextStyle(fontSize: 14)),
                          Row(
                            children: List.generate(7, (dayIndex) {
                              final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              final now = DateTime.now();
                              final todayIndex = now.weekday - 1; // 0=Mon, ..., 6=Sun

                              Color textColor;
                              if (dayIndex < todayIndex) {
                                textColor = Colors.teal; // Past days - green
                              } else if (dayIndex == todayIndex) {
                                textColor = Colors.red; // Current day - red
                              } else {
                                textColor = Colors.black38; // Upcoming - gray
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  dayLabels[dayIndex],
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: dayIndex == todayIndex
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                ),
                              );
                            }),
                          )
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 18, top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFC0FF33), width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            "00",
                            style: TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.bold,
                                fontSize: 28),
                          ),
                          Text(
                            "Defects",
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC0FF33),
        child: const Icon(Icons.list, color: Color(0xFF009688)),
        tooltip: 'Show Categories',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryListPage()),
          );
        },
      ),
    );
  }
}
