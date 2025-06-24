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


  Future<void> _solveDefectAt(String dateTime, String questionKey) async {
    // 1️⃣ VALIDATION
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please toggle “Completed” before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final actionText = _descriptionController.text.trim();
    if (actionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2️⃣ Read supervisor name
    final prefs = await SharedPreferences.getInstance();
    final supervisorName = prefs.getString('full_name') ?? '';

    // 3️⃣ POST with date_time
    final url = Uri.parse('https://esheapp.in/GE/App/set_defect_action.php');
    final payload = {
      'rfid_no'        : widget.rfidNo,
      'date_time'      : dateTime,
      'question_key'   : questionKey,
      'action_text'    : actionText,
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

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
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
        _fetchDefectDetails(); // refresh
      }
    } catch (e) {
      debugPrint('❌ Solve error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: inspections.length,
        itemBuilder: (context, index) {
          final ins = inspections[index];
          final date = ins['date_time'] as String;
          final op = ins['operator_name'] as String;
          final rem = ins['remarks'] as String? ?? '';
          final fails = (ins['defects_identified'] as List)
              .cast<Map<String, dynamic>>();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Text(
                    date
                        .split(' ')
                        .first,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Operator & remarks
                  Text('Operator: $op'),
                  if (rem.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Remarks: $rem'),
                  ],
                  const SizedBox(height: 12),

                  // Defects list
                  const Text(
                    'Defects:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (fails.isEmpty)
                    const Text('None',
                        style: TextStyle(color: Colors.green))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fails.map((f) {
                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${f['question_text']} '
                                      '(Given: ${f['given_answer']}, '
                                      'Expected: ${f['correct_answer']})',
                                ),
                              ),
                              TextButton(
                                onPressed: () => _solveDefectAt(
                                  ins['date_time'] as String,
                                  f['question_key'] as String,
                                ),
                                child: const Text('Solve'),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  // Completed switch & description only for the first (most recent) item
                  if (index == 0) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Completed',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        Switch(
                          value: completed,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.green.shade400,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor:
                          Colors.grey.shade400,
                          onChanged: (v) =>
                              setState(() => completed = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Description / Remarks',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.all(12),
                        hintText: 'Enter any additional notes…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: (completed &&
              _descriptionController.text.trim().isNotEmpty &&
              inspections.isNotEmpty &&
              (inspections.first['defects_identified'] as List).isNotEmpty)
              ? () {
            final firstIns = inspections.first;
            final dt       = firstIns['date_time'] as String;
            final key      = (firstIns['defects_identified'] as List).first['question_key'] as String;
            _solveDefectAt(dt, key);
          }
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: (completed &&
                _descriptionController.text
                    .trim()
                    .isNotEmpty &&
                inspections.isNotEmpty &&
                (inspections.first['defects_identified'] as List)
                    .isNotEmpty)
                ? const Color(0xFFC0FF33)
                : Colors.grey,
          ),
          child: const Text(
            'Save',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF009688),
            ),
          ),
        ),
      ),
    );
  }

// Helper for detail rows:
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}