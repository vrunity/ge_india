import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChecklistPage.dart';

class CheckingPage extends StatefulWidget {
  final String rfidNo;
  final String role;

  const CheckingPage({super.key, required this.rfidNo, required this.role});

  @override
  State<CheckingPage> createState() => _CheckingPageState();
}

class _CheckingPageState extends State<CheckingPage> {
  bool isLoading = false;
  String errorMsg = '';
  final TextEditingController _rfidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rfidController.text = widget.rfidNo;
  }

  Future<void> fetchEquipmentDetails(String rfidNo) async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('full_name') ?? '';

    const String apiUrl = 'https://esheapp.in/GE/App/get_equipment_by_rfid_and_user.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'rfid_no': rfidNo.trim(),
          'full_name': fullName,
          'role': widget.role,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true &&
          data['equipments'] != null &&
          data['equipments'].isNotEmpty) {
        final eq = data['equipments'][0];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChecklistPage(
              operatorName: fullName,
              rfidNo: eq['rfid_no'],
              itemCategory: eq['item_category'],
            ),
          ),
        );
      } else {
        setState(() {
          errorMsg = data['message'] ?? "Not authorized or equipment not found!";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  void onEnterPressed() {
    final rfid = _rfidController.text.trim();
    if (rfid.isEmpty) {
      setState(() => errorMsg = "Please enter RFID number");
      return;
    }
    fetchEquipmentDetails(rfid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Equipment Check", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _rfidController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: "Enter RFID number",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.keyboard_return),
                  tooltip: "Enter",
                  onPressed: onEnterPressed,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 20),
              onSubmitted: (_) => onEnterPressed(),
            ),
            const SizedBox(height: 20),
            if (errorMsg.isNotEmpty)
              Text(
                errorMsg,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
