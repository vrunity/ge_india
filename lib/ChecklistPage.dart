import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'CategoryListPage.dart';
import 'loginpage.dart';

class ChecklistPage extends StatefulWidget {
  final String operatorName;
  final String rfidNo;
  final String itemCategory;

  const ChecklistPage({
    super.key,
    required this.operatorName,
    required this.rfidNo,
    required this.itemCategory,
  });

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  bool isLoading = true;
  bool isSubmitting = false;
  String errorMsg = '';

  List<dynamic> questions = [];
  Map<String, String> answers = {};

  // NEW: controller for remarks
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChecklistQuestions();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> fetchChecklistQuestions() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    const String apiUrl =
        'https://esheapp.in/GE/App/get_checklist_by_category.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'item_category': widget.itemCategory,
        }),
      );

      print("Checklist API response: ${response.body}");

      if (response.statusCode != 200) {
        setState(() {
          errorMsg = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);
      if (data == null || data is! Map) {
        setState(() {
          errorMsg = 'Invalid server response.';
          isLoading = false;
        });
        return;
      }

      if (data['success'] == true && data['questions'] is List) {
        setState(() {
          questions = List<Map<String, dynamic>>.from(data['questions']);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMsg = data['message'] ?? "No questions found.";
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

  Future<void> submitChecklist() async {
    setState(() => isSubmitting = true);

    // convert answers: q1, q2, ...
    final Map<String, String> convertedAnswers = {};
    int idx = 1;
    answers.forEach((_, val) {
      convertedAnswers['q$idx'] = val;
      idx++;
    });

    const apiUrl = 'https://esheapp.in/GE/App/inspection_checklist.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'operator_name': widget.operatorName,
          'rfid_no': widget.rfidNo,
          'answers': convertedAnswers,
          'remarks': _remarksController.text.trim(),    // <-- include remarks
        }),
      );
      setState(() => isSubmitting = false);

      if (!mounted) return;

      if (response.statusCode != 200 || response.body.isEmpty) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content:
            const Text("Server error or empty response. Please try again."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              )
            ],
          ),
        );
        return;
      }

      final data = jsonDecode(response.body);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(data['success'] == true ? "Success" : "Error"),
          content: Text(data['message'] ?? "Unknown response"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (data['success'] == true) {
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() => isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg.isNotEmpty
          ? Center(
        child: Text(
          errorMsg,
          style: const TextStyle(fontSize: 16, color: Colors.red),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Operator: ${widget.operatorName}",
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Equipment: ${widget.itemCategory}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "RFID: ${widget.rfidNo}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Divider(height: 32),

          // render each question
          ...questions.map((q) {
            final qId = q['id'].toString();
            final text = q['question'];
            final a = q['option_a'];
            final b = q['option_b'];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(a),
                          selected: answers[qId] == "A",
                          onSelected: (_) {
                            setState(() => answers[qId] = "A");
                          },
                          selectedColor: Colors.green,
                          backgroundColor: Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: answers[qId] == "A"
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 14),
                        ChoiceChip(
                          label: Text(b),
                          selected: answers[qId] == "B",
                          onSelected: (_) {
                            setState(() => answers[qId] = "B");
                          },
                          selectedColor: Colors.green,
                          backgroundColor: Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: answers[qId] == "B"
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),


          // ─── NEW REMARKS FIELD ────────────────────────
          TextField(
            controller: _remarksController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Remarks',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.teal, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
              ),
            ),
          ),



          const SizedBox(height: 24),

          // ─── SUBMIT BUTTON ────────────────────────────
          isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
            onPressed: submitChecklist,
            icon: const Icon(Icons.check),
            label: const Text("Submit Checklist"),
          ),
        ],
      ),
    );
  }
}
