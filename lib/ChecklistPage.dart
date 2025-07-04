import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class ChecklistPage extends StatefulWidget {
  final String operatorName;
  final String rfidNo;
  final String Location;
  final String itemCategory;
  final String description;   // <--- Add this
  const ChecklistPage({
    super.key,
    required this.operatorName,
    required this.rfidNo,
    required this.Location,
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

  /// 'en' or 'ta'
  String _selectedLanguage = 'en';

  // NEW: controller for remarks
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChecklistQuestions();
    for (final q in questions) {
      final qId = q['id'].toString();
      remarkControllers[qId] =
          TextEditingController(text: remarksMap[qId] ?? '');
      // Ask language immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseLanguage());
    }
  }
// At the top of your widget file, add:
  Color _getChipColor({required String option, required String? userAnswer, required String correct}) {
    if (userAnswer == null || userAnswer != option) return Colors.grey.shade200;
    if (userAnswer == correct) return Colors.green;
    return Colors.redAccent;
  }
  Color _getChipTextColor({required String option, required String? userAnswer, required String correct}) {
    if (userAnswer == null || userAnswer != option) return Colors.black;
    return Colors.white;
  }
  @override
  void dispose() {
    for (final controller in remarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseLanguage() async {
    final lang = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Select Language'),
            content: const Text('இது தமிழ் / This is English'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('ta'),
                child: const Text('தமிழ்'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('en'),
                child: const Text('English'),
              ),
            ],
          ),
    );

    if (lang != null) {
      setState(() {
        _selectedLanguage = lang;
        isLoading = true;
      });
      await fetchChecklistQuestions();
    }
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
          'language': _selectedLanguage,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.only(
                  top: 20, left: 20, right: 20, bottom: 8),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700],
                      size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          const TextSpan(
                              text: 'Critical defect(s) found  equipment blocked by '),
                          TextSpan(
                              text: 'EHS team',
                              style: TextStyle(color: Colors.red[700],
                                  fontWeight: FontWeight.bold)),
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
                            Icon(Icons.error_outline, color: Colors.red[400],
                                size: 22),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
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


  /// 1) Make sure your “all answered + remarks” check uses controller.text
  bool isChecklistValid() {
    for (final q in questions) {
      final qId = q['id'].toString();
      final answer = answers[qId];
      // 1a) Every question must have an answer
      if (answer == null) return false;
      // 1b) If the answer is a defect, its remark controller must be non-empty
      if (answer != q['correct_option']) {
        final remark = remarkControllers[qId]?.text.trim() ?? '';
        if (remark.isEmpty) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final _scrollController = ScrollController();

    // ensure controllers exist
    for (final q in questions) {
      final qId = q['id'].toString();
      remarkControllers.putIfAbsent(qId, () => TextEditingController());
    }

    void showValidationError(String msg, {int? scrollToIndex}) async {
      if (scrollToIndex != null && _scrollController.hasClients) {
        _scrollController.animateTo(
          (scrollToIndex * 140.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Incomplete"),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK")),
          ],
        ),
      );
    }

    Future<void> submitChecklist() async {
      // 1. Quick validity check
      if (!isChecklistValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please answer all questions and enter remarks for all defect answers.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
        return;
      }

      // 2. Ensure all defect answers have a remark, scrolling to the first missing one
      for (int idx = 0; idx < questions.length; idx++) {
        final q = questions[idx];
        final qId = q['id'].toString();
        final correctOption = q['correct_option'] as String;
        final userAnswer = answers[qId];
        if (userAnswer != null && userAnswer != correctOption) {
          final remark = remarkControllers[qId]?.text.trim() ?? '';
          if (remark.isEmpty) {
            setState(() => isSubmitting = false);
            showValidationError(
              "Please enter a remark for all defect answers.",
              scrollToIndex: idx,
            );
            return;
          }
        }
      }

      setState(() => isSubmitting = true);

      // 3. Build the maps of answers & remarks from controllers
      final Map<String, String> convertedAnswers = {};
      final Map<String, String> convertedRemarks = {};
      for (final q in questions) {
        final qId = q['id'].toString();
        final answer = answers[qId];
        final remarkText = remarkControllers[qId]?.text.trim() ?? '';
        if (answer != null) {
          convertedAnswers[qId] = answer;
          if (answer != q['correct_option'] && remarkText.isNotEmpty) {
            convertedRemarks[qId] = remarkText;
          }
        }
      }

      // 4. Load phone number from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone') ?? '';

      // 5. Assemble payload
      final payload = {
        'operator_name': widget.operatorName,
        'rfid_no': widget.rfidNo,
        'answers': convertedAnswers,
        'remarks': convertedRemarks,
        'phone': phoneNumber,
      };

      try {
        // 6. Send to server
        final response = await http.post(
          Uri.parse('https://esheapp.in/GE/App/inspection_checklist.php'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );

        setState(() => isSubmitting = false);

        if (!mounted) return;

        // 7. Parse and show result dialog
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
                  if (data['success'] == true) Navigator.of(context).maybePop();
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      } catch (e, stacktrace) {
        // 8. Handle network or JSON errors
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
        backgroundColor: const Color(0xFF00807B),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg.isNotEmpty
          ? Center(child: Text(errorMsg, style: const TextStyle(color: Colors.red)))
          : ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ── LANGUAGE PICKER ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: _selectedLanguage == 'en',
                onSelected: (on) {
                  if (on && _selectedLanguage != 'en') {
                    setState(() {
                      _selectedLanguage = 'en';
                      isLoading = true;
                    });
                    fetchChecklistQuestions();
                  }
                },
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('தமிழ்'),
                selected: _selectedLanguage == 'ta',
                onSelected: (on) {
                  if (on && _selectedLanguage != 'ta') {
                    setState(() {
                      _selectedLanguage = 'ta';
                      isLoading = true;
                    });
                    fetchChecklistQuestions();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── HEADER ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Operator: ${widget.operatorName}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("Equipment: ${widget.itemCategory}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("RFID: ${widget.rfidNo}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),const SizedBox(height: 4),
                Text("Location: ${widget.Location}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("Description: ${widget.description}",
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.teal,
                    )),
              ],
            ),
          ),
          const Divider(height: 32),

          // ── QUESTIONS ──
          // Inside your build method (or wherever you map questions):
          ...questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q   = entry.value;
            final qId = q['id'].toString();

            final questionText = (q['question'] ?? '').toString();
            final a            = (q['option_a'] ?? '').toString();
            final b            = (q['option_b'] ?? '').toString();
            final correct      = (q['correct_option'] ?? 'A').toString();
            final userAnswer   = answers[qId];
            final isDefect     = userAnswer != null && userAnswer != correct;
            final isCritical   = (q['critical'] == 1 || q['critical'] == '1');
            final ctl          = remarkControllers[qId]!;

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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // question
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCritical)
                          const Text('* ',
                              style: TextStyle(color: Colors.red, fontSize: 20)),
                        Expanded(
                          child: Text(
                            "Q${idx + 1}. $questionText",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDefect ? Colors.red.shade700 : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // options
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(a),
                            selected: userAnswer == 'A',
                            onSelected: (_) => setState(() {
                              answers[qId] = 'A';
                              ctl.clear();
                            }),
                            selectedColor: _getChipColor(option: 'A', userAnswer: userAnswer, correct: correct),
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: _getChipTextColor(option: 'A', userAnswer: userAnswer, correct: correct),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(b),
                            selected: userAnswer == 'B',
                            onSelected: (_) => setState(() {
                              answers[qId] = 'B';
                              ctl.clear();
                            }),
                            selectedColor: _getChipColor(option: 'B', userAnswer: userAnswer, correct: correct),
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: _getChipTextColor(option: 'B', userAnswer: userAnswer, correct: correct),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // remark if defect
                    if (isDefect)
                      TextField(
                        controller: ctl,
                        onChanged: (t) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Enter remark for defect',
                          labelStyle: const TextStyle(color: Colors.red),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // ── SUBMIT ──
          isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
            onPressed: submitChecklist,
            icon: const Icon(Icons.check),
            label: const Text("Submit Checklist"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor:
              isChecklistValid() ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}