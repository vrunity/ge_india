import 'package:flutter/material.dart';

class EquipmentListPage extends StatelessWidget {
  final String category;
  final List<dynamic> equipments;
  final String userRole; // "supervisor", "area_manager", etc.

  const EquipmentListPage({
    super.key,
    required this.category,
    required this.equipments,
    this.userRole = "operator",
  });

  bool isCheckedOkDay(String role) {
    final now = DateTime.now();
    if (role == "supervisor") {
      return now.day % 7 == 0;
    } else if (role == "area_manager") {
      return now.day == 15 || now.day == 30 || now.day == 31;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(category, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: equipments.isEmpty
          ? Center(
        child: Text(
          "No equipment found for this category.",
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: equipments.length,
        itemBuilder: (context, idx) {
          final eq = equipments[idx];
          String eqNum = '';
          final desc = eq['description'] ?? '';
          final match = RegExp(r'(\d+)').firstMatch(desc);
          if (match != null) eqNum = match.group(0) ?? '';

          // Button state logic
          final enableCheckedOk = isCheckedOkDay(userRole);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "${eq['item_category'] ?? ''} - ${eq['id'] ?? eqNum}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 10, top: 2),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFC0FF33), width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
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
                  const SizedBox(height: 8),
                  const Text('This Week',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  Row(
                    children: List.generate(7, (dayIdx) {
                      Color textColor;
                      if (dayIdx < todayIndex) {
                        textColor = Colors.teal;
                      } else if (dayIdx == todayIndex) {
                        textColor = Colors.red;
                      } else {
                        textColor = Colors.black38;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          days[dayIdx],
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            decoration: dayIdx == todayIndex
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (userRole == "supervisor" || userRole == "area_manager")
                    Center(
                      child: AbsorbPointer(
                        absorbing: !enableCheckedOk,
                        child: ElevatedButton(
                          onPressed: enableCheckedOk
                              ? () {
                            // Your "Checked ok" logic here
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 6,
                            backgroundColor: enableCheckedOk
                                ? Colors.transparent
                                : Colors.grey,
                            shadowColor: Colors.black45,
                          ),
                          child: Ink(
                            decoration: enableCheckedOk
                                ? BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF009688),
                                  Color(0xFF43E97B)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12,
                                    offset: Offset(0, 6),
                                    blurRadius: 8)
                              ],
                            )
                                : null,
                            child: Container(
                              width: 160,
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Checked ok',
                                style: TextStyle(
                                  color: enableCheckedOk
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
