import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class ChecklistPage extends StatefulWidget {
  final String operatorName;
  final String rfidNo;
  final String itemCategory;
  final String description;   // <--- Add this
  const ChecklistPage({
    super.key,
    required this.operatorName,
    required this.rfidNo,
    required this.itemCategory,
    required this.description, // <--- Add this
  });

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  bool isLoading = true;
  bool isSubmitting = false;
  String errorMsg = '';
  final Map<String, TextEditingController> remarkControllers = {};
  List<dynamic> questions = [];
  Map<String, String> answers = {};
  Map<String, String> remarksMap = {};

  // NEW: controller for remarks
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChecklistQuestions();
    for (final q in questions) {
      final qId = q['id'].toString();
      remarkControllers[qId] = TextEditingController(text: remarksMap[qId] ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in remarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> fetchChecklistQuestions() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    const String apiUrl = 'https://esheapp.in/GE/App/get_checklist_by_category.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'item_category': widget.itemCategory,
          'rfid_no': widget.rfidNo, // Make sure widget.rfidNo is set!
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

      // Handle checklist block for critical defect
      if (data['block_critical'] == true) {
        List<dynamic> defects = data['defects'] ?? [];

        setState(() {
          errorMsg = (data['title'] ?? 'Checklist Blocked');
          isLoading = false;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          const TextSpan(
                              text: 'Critical defect(s) found  equipment blocked by '),
                          TextSpan(
                              text: 'EHS team',
                              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...defects.map<Widget>((d) {
                      String q = d['question'] ?? '';
                      String r = d['remark'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[400], size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        fontSize: 16,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Remark: $r',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      "Please contact EHS team to resolve the critical defect(s).",
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('OK', style: TextStyle(letterSpacing: 1)),
                )
              ],
            );
          },
        );
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


  bool isChecklistValid() {
    for (final q in questions) {
      final qId = q['id'].toString();
      final correctOption = q['correct_option'] as String;
      final userAnswer = answers[qId];

      if (userAnswer == null) return false; // not all answered

      if (userAnswer != correctOption) {
        final remark = remarksMap[qId]?.trim() ?? '';
        if (remark.isEmpty) return false; // defect answer missing remark
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final _scrollController = ScrollController();

    // Ensure each remark field has a controller (if not, create one)
    for (final q in questions) {
      final qId = q['id'].toString();
      if (!remarkControllers.containsKey(qId)) {
        remarkControllers[qId] = TextEditingController(text: remarksMap[qId] ?? '');
      }
    }

    void showValidationError(String message, {int? scrollToIndex}) async {
      if (scrollToIndex != null && _scrollController.hasClients) {
        _scrollController.animateTo(
          (scrollToIndex * 140.0).clamp(
              0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Incomplete"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }

    Future<void> submitChecklist() async {
      if (!isChecklistValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please answer all questions and enter remarks for all defect answers.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
        return;
      }
      setState(() => isSubmitting = true);

      // Validation: all defect answers must have a remark
      for (int idx = 0; idx < questions.length; idx++) {
        final q = questions[idx];
        final qId = q['id'].toString();
        final correctOption = q['correct_option'] as String;
        final userAnswer = answers[qId];
        if (userAnswer != null && userAnswer != correctOption) {
          final remark = remarkControllers[qId]?.text.trim() ?? '';
          if (remark.isEmpty) {
            setState(() => isSubmitting = false);
            showValidationError("Please enter a remark for all defect answers.", scrollToIndex: idx);
            return;
          }
        }
      }

      // Build answers and remarks to send
      final Map<String, String> convertedAnswers = {};
      final Map<String, String> convertedRemarks = {};

      for (final q in questions) {
        final qId = q['id'].toString();
        final answer = answers[qId];
        final remark = remarkControllers[qId]?.text.trim();
        if (answer != null) convertedAnswers[qId] = answer;
        if (remark != null && remark.isNotEmpty) {
          convertedRemarks[qId] = remark;
        }
      }

      const apiUrl = 'https://esheapp.in/GE/App/inspection_checklist.php';

      try {
        // GET PHONE FROM SHARED PREFERENCES
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final phoneNumber = prefs.getString('phone') ?? '';
        // Debug print: What is stored in shared preferences?
        print("Loaded phoneNumber from SharedPreferences: $phoneNumber");

        // Build the payload
        final Map<String, dynamic> payload = {
          'operator_name': widget.operatorName,
          'rfid_no': widget.rfidNo,
          'answers': convertedAnswers,
          'remarks': convertedRemarks,
          'phone': phoneNumber,
        };

        // Debug print: Full API payload
        print("API Payload: ${jsonEncode(payload)}");

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );

        setState(() => isSubmitting = false);

        if (!mounted) return;

        // Debug print: API response
        print("API Response: ${response.body}");

        final data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : {};

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
      } catch (e, stacktrace) {
        setState(() => isSubmitting = false);
        if (!mounted) return;
        print("Submission error: $e\n$stacktrace");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e')),
        );
      }
    }
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Operator: ${widget.operatorName}",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "Equipment: ${widget.itemCategory}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "RFID: ${widget.rfidNo}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "Description: ${widget.description}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: Colors.teal,
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 32),

          // Questions
          ...questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            final qId = q['id'].toString();
            final questionText = q['question'] as String;
            final a = q['option_a'] as String;
            final b = q['option_b'] as String;
            final correctOption = q['correct_option'] as String;
            final userAnswer = answers[qId];
            final isDefect = userAnswer != null && userAnswer != correctOption;
            final controller = remarkControllers[qId]!;
            final isCritical = (q['critical'] == 1 || q['critical'] == '1');

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: isDefect ? 6 : 2,
              shadowColor: isDefect ? Colors.redAccent : Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDefect ? Colors.redAccent : Colors.teal.shade200,
                  width: isDefect ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- QUESTION TITLE WITH CRITICAL ASTERISK ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCritical) ...[
                          Text(
                            '* ',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            "Q${idx + 1}. $questionText",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: isDefect ? Colors.red.shade700 : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(a, style: const TextStyle(fontSize: 15)),
                            selected: userAnswer == "A",
                            onSelected: (_) {
                              setState(() {
                                answers[qId] = "A";
                                if (controller.text.isNotEmpty) {
                                  controller.clear();
                                  remarksMap[qId] = "";
                                }
                              });
                            },
                            selectedColor: Colors.teal,
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: userAnswer == "A" ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(b, style: const TextStyle(fontSize: 15)),
                            selected: userAnswer == "B",
                            onSelected: (_) {
                              setState(() {
                                answers[qId] = "B";
                                if (controller.text.isNotEmpty) {
                                  controller.clear();
                                  remarksMap[qId] = "";
                                }
                              });
                            },
                            selectedColor: Colors.redAccent,
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: userAnswer == "B" ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isDefect)
                      TextField(
                        controller: controller,
                        onChanged: (txt) {
                          setState(() => remarksMap[qId] = txt);
                        },
                        decoration: InputDecoration(
                          labelText: 'Enter remark for defect',
                          labelStyle: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Required for defect answers',
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // Submit Button
          isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
            onPressed: isSubmitting ? null : submitChecklist,
            icon: Icon(Icons.check, color: Colors.white),
            label: const Text("Submit Checklist"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(180, 48),
              textStyle: const TextStyle(fontSize: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: isChecklistValid() ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }
}
