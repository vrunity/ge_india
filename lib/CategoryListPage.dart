import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'EquipmentListPage.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  List<String> categories = [];
  bool isLoading = true;
  String? role;
  String serverFeedback = '';

  @override
  void initState() {
    super.initState();
    fetchApprovedCategories();
  }

  Future<void> fetchApprovedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = (prefs.getString('full_name') ?? '').trim();
    final userRole = (prefs.getString('category') ?? 'operator').trim().toLowerCase();

    setState(() {
      isLoading = true;
    });

    const String apiUrl = 'https://esheapp.in/GE/App/get_approved_categories.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'full_name': fullName, 'role': userRole}),  // <-- send role!
      );

      final data = jsonDecode(response.body);

      setState(() {
        categories = (data['success'] == true) ? List<String>.from(data['categories']) : [];
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        categories = [];
        isLoading = false;
      });
    }
  }

  Future<void> fetchEquipmentsForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final String fullName = (prefs.getString('full_name') ?? '').trim();

    // Normalize role for backend compatibility
    String userRole = (prefs.getString('category') ?? 'operator').trim().toLowerCase();
    // Replace spaces with underscores (so "area manager" -> "area_manager")
    userRole = userRole.replaceAll(' ', '_');

    if (fullName.isEmpty || userRole.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User info missing, please login again.')),
        );
      }
      return;
    }

    const String apiUrl = 'https://esheapp.in/GE/App/get_equipment_for_category.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'full_name': fullName,
          'category': category,
          'role': userRole,
        }),
      );

      print('Server response: ${response.body}'); // Debug

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Optional: Show server message if any error or info
        if (data['success'] != true || (data['message'] != null && data['message'].toString().isNotEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server: ${data['message'] ?? 'No message'}')),
          );
        }

        final fetchedEquipments = (data['success'] == true) ? data['equipments'] ?? [] : [];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipmentListPage(
              category: category,
              equipments: fetchedEquipments,
              userRole: userRole,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}\n${response.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading equipment: $e')),
        );
      }
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.notifications, color: Color(0xFFFFFF00)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
          ? Center(
        child: Text(
          "No categories found.\nContact admin if you believe this is an error.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final category = categories[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => fetchEquipmentsForCategory(category),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFC0FF33), width: 2),
                  ),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  elevation: 2,
                ),
                child: Text(category, textAlign: TextAlign.center),
              ),
            ),
          );
        },
      ),
    );
  }
}
