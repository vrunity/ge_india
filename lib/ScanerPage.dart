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
  late AnimationController _controller;
  late Animation<double> _animation;

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
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      setState(() {
        _isScanned = true;
        _scannedValue = barcodes.first.rawValue;
      });
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop(_scannedValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double scanBoxSize = MediaQuery.of(context).size.width * 0.74;
    final double verticalMargin = MediaQuery.of(context).size.height * 0.18;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Scan QR/Barcode', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final left = (w - scanBoxSize) / 2;
            final top = verticalMargin;

            return Stack(
              children: [
                // Dimming with punch hole
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.58),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: w,
                        height: h,
                        color: Colors.black.withOpacity(0.7),
                      ),
                      Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: scanBoxSize,
                          height: scanBoxSize,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // White border
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 14,
                        )
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
                // Instruction text
                Positioned(
                  left: 0,
                  right: 0,
                  top: top + scanBoxSize + 30,
                  child: const Center(
                    child: Text(
                      "Place QR or Barcode inside the box",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Scanned value overlay
                if (_isScanned && _scannedValue != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Scanned: $_scannedValue",
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Scan line that moves up and down within the central 60% (NOT the whole box)
class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF2AE4FF)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    // Move line between 20% and 80% of box height (centered movement)
    final double minY = size.height * 0.2;
    final double maxY = size.height * 0.8;
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
