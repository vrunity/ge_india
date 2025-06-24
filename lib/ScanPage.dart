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

class _OperatorDashboardState extends State<OperatorDashboard> {
  final TextEditingController _rfidController = TextEditingController();
  String errorMsg = '';
  bool isLoading = false;

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

      // Always print the raw response for debugging
      print('API response: ${response.body}');

      // Check for an empty response or bad status
      if (response.statusCode != 200 || response.body.isEmpty) {
        setState(() {
          isLoading = false;
          errorMsg = "Server error. Please try again.";
        });
        return;
      }

      final data = jsonDecode(response.body);

      // Defensive: handle unexpected response structure
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
            builder: (_) => ChecklistPage(
              operatorName: fullName,
              rfidNo: eq['rfid_no'],
              itemCategory: eq['item_category'],
            ),
          ),
        );
      } else {
        setState(() {
          isLoading = false;
          errorMsg = data['message'] ?? "Not authorized or equipment not found!";
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.notifications, color: Color(0xFFFFFF00)),
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
              opacity: 0.11,
              child: Image.asset(
                'assets/bg_wave.png',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFC0FF33),
                        child: const Icon(Icons.person, color: Color(0xFF009688), size: 34),
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        "Welcome, Operator!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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
                              MaterialPageRoute(builder: (_) => const Scanerpage()),
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
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Instructions Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Color(0xFFC0FF33), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
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
                        side: const BorderSide(color: Color(0xFFC0FF33), width: 1.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF009688), size: 22),
                      label: const Text(
                        "Need Help?",
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        // TODO: Show help or support dialog
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
}
