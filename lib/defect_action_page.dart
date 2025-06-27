import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DefectActionPage extends StatefulWidget {
  final String rfidNo;
  final String itemCategory;

  const DefectActionPage({
    Key? key,
    required this.rfidNo,
    required this.itemCategory,
  }) : super(key: key);

  @override
  State<DefectActionPage> createState() => _DefectActionPageState();
}

class _DefectActionPageState extends State<DefectActionPage> {
  bool isLoading = true;
  String tokenNo = '';
  String itemName = '';
  String operatorName = '';
  String defectDetails = '';
  bool completed = false;
  final TextEditingController _descriptionController = TextEditingController();
  List<Map<String, String>> allAnswers = [];
  List<Map<String, dynamic>> inspections = [];
  List<Map<String, String>> allDefectQuestions = [];
  List<Map<String, String>> allQuestions = [];

  /// Each map now also contains 'question_key'
  List<Map<String, String>> defectsIdentified = [];

  @override
  void initState() {
    super.initState();
    _fetchDefectDetails();
  }

  Future<void> _fetchDefectDetails() async {
    setState(() => isLoading = true);

    final url = Uri.parse(
      'https://esheapp.in/GE/App/get_defect_details.php',
    );

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rfid_no': widget.rfidNo}),
      );
      print('🛰️ getDefectDetails → status ${resp.statusCode}');
      print('🛰️ getDefectDetails → body   ${resp.body}');

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true || data['inspections'] == null) {
        throw Exception(data['message'] ?? 'No records found');
      }

      // Parse inspections array
      inspections = [];
      for (var ins in (data['inspections'] as List)) {
        inspections.add(Map<String, dynamic>.from(ins));
      }

      setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
      }
    }
  }


  bool isSubmitting = false; // Add in your State class

  Future<bool> _solveDefectAt(String dateTime, String questionKey, String actionText) async {
    if (isSubmitting) return false;
    setState(() => isSubmitting = true);

    // 1️⃣ Validation
    if (actionText.trim().isEmpty) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // 2️⃣ Read supervisor name from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final supervisorName = (prefs.getString('full_name') ?? '').trim();

    // 3️⃣ Compose payload for POST
    final url = Uri.parse('https://esheapp.in/GE/App/set_defect_action.php');
    final payload = {
      'rfid_no': widget.rfidNo,        // Ensure your widget has rfidNo
      'date_time': dateTime,
      'question_key': questionKey,
      'action_text': actionText.trim(),
      'supervisor_name': supervisorName,
    };

    debugPrint('💾 Solving defect payload: $payload');

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      debugPrint('💾 Solve [${resp.statusCode}]: ${resp.body}');

      setState(() => isSubmitting = false);

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${resp.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final ok = data['success'] == true;
      final msg = data['message'] ?? (ok ? 'Solved' : 'Failed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok && mounted) {
        _fetchDefectDetails(); // refresh defect list/details
      }
      return ok;
    } catch (e) {
      setState(() => isSubmitting = false);
      debugPrint('❌ Solve error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Defect Action',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : inspections.isEmpty
          ? const Center(
        child: Text(
          'No inspection records.',
          style: TextStyle(color: Colors.white),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: inspections.length,
        itemBuilder: (context, index) {
          final ins = inspections[index];
          final date = ins['date_time'] as String;
          final op = ins['operator_name'] as String? ?? '';
          final fails = (ins['defects_identified'] as List)
              .cast<Map<String, dynamic>>();
          final defectActions = ins['defect_action'] as Map<String, dynamic>? ?? {};

          return Card(
            margin: const EdgeInsets.only(bottom: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with date and operator
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.teal[400], size: 18),
                      const SizedBox(width: 7),
                      Text(
                        date.split(' ').first,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF009688),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.person, size: 18, color: Colors.teal[300]),
                      const SizedBox(width: 3),
                      Text(
                        op,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 22, color: Colors.teal),
                  const SizedBox(height: 8),

                  const Text(
                    'Defects:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 7),

                  if (fails.isEmpty)
                    const Text('None', style: TextStyle(color: Colors.green, fontSize: 15))
                  else
                    ...fails.map((f) {
                      final qKey = f['question_key'] as String;
                      final questionText = f['question_text'] as String;
                      final defectRemark = (f['remark'] as String?) ?? '';
                      final previousAction = defectActions[qKey] as Map<String, dynamic>?;

                      // Use controller for each defect description
                      final TextEditingController controller =
                      defectControllers.putIfAbsent(qKey, () => TextEditingController());

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3), width: 1.1),
                          borderRadius: BorderRadius.circular(13),
                          color: Colors.red[50]?.withOpacity(0.13),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$questionText\n(Given: ${f['given_answer']} | Expected: ${f['correct_answer']})',
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (defectRemark.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 8),
                                child: Text(
                                  'Remark: $defectRemark',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.deepOrange,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),

                            // Description input and Solve button
                            if (previousAction == null) ...[
                              TextField(
                                controller: controller,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Describe action taken…',
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.all(12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final txt = controller.text.trim();
                                    if (txt.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text("Please enter action description")));
                                      return;
                                    }
                                    _solveDefectAt(date, qKey, txt);
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Solve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9)),
                                  ),
                                ),
                              ),
                            ],
                            // Show last solved action if available
                            if (previousAction != null) ...[
                              const SizedBox(height: 7),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  border: Border.all(color: Colors.green, width: 1),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Solved: ${previousAction['action']}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (previousAction['solve_time'] != null)
                                      Text(
                                        "at ${previousAction['solve_time']}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
// Controller Map (put this in your State class)
  final Map<String, TextEditingController> defectControllers = {};
}