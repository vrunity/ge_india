import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Scanerpage extends StatefulWidget {
  const Scanerpage({super.key});

  @override
  State<Scanerpage> createState() => _ScanerpageState();
}

class _ScanerpageState extends State<Scanerpage> with SingleTickerProviderStateMixin {
  bool _isScanned = false;
  String? _scannedValue;
  String? _rfidValue;
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _rfidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _rfidController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      setState(() {
        _isScanned = true;
        _scannedValue = barcodes.first.rawValue;
        _rfidValue = _extractRfid(_scannedValue!);
        if (_rfidValue != null) {
          _rfidController.text = _rfidValue!;
        }
      });
    }
  }

  /// Extracts RFID value from URL. Works for ...?RFID=XXX, ...?rfid=XXX, ...?RFIDno=XXX, ...?rfidno=XXX
  String? _extractRfid(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      // Try all possible param names
      return uri.queryParameters['RFIDno'] ??
          uri.queryParameters['rfidno'] ??
          uri.queryParameters['RFID'] ??
          uri.queryParameters['rfid'];
    }
    // Fallback: Regex for any case/variant
    final exp = RegExp(r"(RFIDno|RFID)=([A-Za-z0-9]+)", caseSensitive: false);
    final match = exp.firstMatch(url);
    if (match != null) return match.group(2); // group(2) is after =
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final double scanBoxSize = MediaQuery.of(context).size.width * 0.74;
    final double verticalMargin = MediaQuery.of(context).size.height * 0.17;

    return Scaffold(
      backgroundColor: const Color(0xFF171C24),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan QR/Barcode',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          // Subtle dark overlay except scan area
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final left = (w - scanBoxSize) / 2;
            final top = verticalMargin;

            return Stack(
              children: [
                // Dimming with a clear scan area
                IgnorePointer(
                  child: Container(
                    width: w,
                    height: h,
                    color: Colors.black.withOpacity(0.32),
                  ),
                ),
                // The scan area stays sharp and white
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.tealAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                // Animated scan line
                Positioned(
                  left: left,
                  top: top,
                  child: SizedBox(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _ScanLinePainter(_animation.value),
                        );
                      },
                    ),
                  ),
                ),
                // Instruction
                Positioned(
                  left: 0,
                  right: 0,
                  top: top + scanBoxSize + 28,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.47),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.2), width: 1.0),
                      ),
                      child: const Text(
                        "Place QR or Barcode inside the box",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                // RFID TextField at the bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Material(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _rfidController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                letterSpacing: 1.2,
                              ),
                              cursorColor: Colors.tealAccent,
                              decoration: InputDecoration(
                                labelText: "RFID Number",
                                labelStyle: TextStyle(
                                    color: Colors.tealAccent.shade100,
                                    fontWeight: FontWeight.w500
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.tealAccent,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.tealAccent.withOpacity(0.7),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.tealAccent,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.numbers, color: Colors.tealAccent),
                              ),
                            ),
                            const SizedBox(height: 13),
                            if (_isScanned)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.done, color: Colors.white),
                                label: const Text("Use this RFID"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 34),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 7,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop(_rfidController.text);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Scanned value overlay (top-center)
                if (_isScanned && _scannedValue != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top - 48,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700.withOpacity(0.89),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Scanned: $_scannedValue",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final double minY = size.height * 0.23;
    final double maxY = size.height * 0.77;
    final double y = minY + (maxY - minY) * progress;
    canvas.drawLine(
      Offset(10, y),
      Offset(size.width - 10, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}
