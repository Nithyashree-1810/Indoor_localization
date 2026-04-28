import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LostItemFinderApp());
}

class LostItemFinderApp extends StatelessWidget {
  const LostItemFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Lost Item Finder",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {

  String status = "Press Scan to Start";
  String proximity = "Unknown";
  bool isScanning = false;
  bool itemFound = false;

  // Ping times in ms — lower = closer
  int pingMs = -1;

  // For continuous scanning
  Timer? _scanTimer;
  int _consecutiveFails = 0;

  late AnimationController radarController;
  late AnimationController pulseController;
  late AnimationController dotController;

  double blipAngle = 1.0;
  double blipRadius = 0.5;

  @override
  void initState() {
    super.initState();

    radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    radarController.dispose();
    pulseController.dispose();
    dotController.dispose();
    super.dispose();
  }

  // ----------- Core Logic -----------

  // Ping the ESP32 and measure round-trip time
  Future<int?> _pingESP32() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse("http://192.168.4.1/ping"))
          .timeout(const Duration(seconds: 2));
      stopwatch.stop();
      if (response.statusCode == 200 && response.body.trim() == "OK") {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    stopwatch.stop();
    return null;
  }

  String _proximityFromPing(int ms) {
    // Lower ping = phone is closer to ESP32
    if (ms < 30)  return "Very Close";
    if (ms < 80)  return "Nearby";
    if (ms < 200) return "Far Away";
    return "Very Far";
  }

  double _blipRadiusFromPing(int ms) {
    if (ms < 30)  return 0.18;
    if (ms < 80)  return 0.42;
    if (ms < 200) return 0.68;
    return 0.86;
  }

  // Single scan
  Future<void> _doSingleScan() async {
    final ms = await _pingESP32();

    if (!mounted) return;

    if (ms != null) {
      _consecutiveFails = 0;
      blipAngle = Random().nextDouble() * 2 * pi;
      blipRadius = _blipRadiusFromPing(ms);
      dotController.forward(from: 0);

      setState(() {
        pingMs = ms;
        proximity = _proximityFromPing(ms);
        status = "Item Found!";
        itemFound = true;
      });
    } else {
      _consecutiveFails++;
      if (_consecutiveFails >= 3) {
        setState(() {
          status = "Item Not Found";
          proximity = "Unknown";
          pingMs = -1;
          itemFound = false;
        });
      }
    }
  }

  // Start continuous scanning every 1 second
  void startScanning() {
    if (isScanning) return;
    _consecutiveFails = 0;

    setState(() {
      isScanning = true;
      status = "Scanning…";
      itemFound = false;
    });

    _doSingleScan(); // immediate first scan
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _doSingleScan();
    });
  }

  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    setState(() {
      isScanning = false;
      status = "Scan Stopped";
    });
  }

  Future<void> triggerBuzzer() async {
    try {
      await http
          .get(Uri.parse("http://192.168.4.1/trigger"))
          .timeout(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Buzzer triggered! 🔔"),
            backgroundColor: Color(0xFF00E5FF),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to trigger buzzer"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color get _statusColor {
    if (status == "Item Found!") return const Color(0xFF00FF88);
    if (status.contains("Not Found") || status.contains("Failed")) {
      return Colors.redAccent;
    }
    return const Color(0xFF00E5FF);
  }

  // ----------- UI -----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [

            // ---- TOP BAR ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LOST ITEM\nFINDER",
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      height: 1.2,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isScanning
                            ? Colors.amber.withOpacity(0.6)
                            : const Color(0xFF00E5FF).withOpacity(0.35),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: isScanning
                          ? Colors.amber.withOpacity(0.08)
                          : Colors.transparent,
                    ),
                    child: Text(
                      isScanning ? "● SCANNING" : "● READY",
                      style: TextStyle(
                        color: isScanning
                            ? Colors.amber
                            : const Color(0xFF00E5FF),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- STATUS ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _statusColor,
                  letterSpacing: 2,
                ),
                child: Text(status.toUpperCase()),
              ),
            ),

            const SizedBox(height: 8),

            // ---- RADAR ----
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = min(
                            constraints.maxWidth, constraints.maxHeight) *
                        0.92;
                    return SizedBox(
                      width: size,
                      height: size,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          radarController,
                          pulseController,
                          dotController,
                        ]),
                        builder: (context, _) {
                          return CustomPaint(
                            painter: RadarPainter(
                              sweepValue: radarController.value,
                              pulseValue: pulseController.value,
                              dotFade: dotController.value,
                              itemFound: itemFound,
                              blipAngle: blipAngle,
                              blipRadius: blipRadius,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // ---- INFO STRIP ----
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1526),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoTile("PROXIMITY", proximity),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                  ),
                  _infoTile(
                    "RESPONSE",
                    pingMs >= 0 ? "${pingMs}ms" : "—",
                  ),
                ],
              ),
            ),

            // ---- BUTTONS ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: isScanning ? stopScanning : startScanning,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        decoration: BoxDecoration(
                          color: isScanning
                              ? Colors.redAccent.withOpacity(0.15)
                              : const Color(0xFF00E5FF),
                          borderRadius: BorderRadius.circular(14),
                          border: isScanning
                              ? Border.all(
                                  color: Colors.redAccent.withOpacity(0.5))
                              : null,
                          boxShadow: isScanning
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Center(
                          child: Text(
                            isScanning ? "■  STOP" : "SCAN ITEM",
                            style: TextStyle(
                              color: isScanning
                                  ? Colors.redAccent
                                  : const Color(0xFF0A0E1A),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: triggerBuzzer,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFF00E5FF).withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "🔔  BUZZ",
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF00E5FF).withOpacity(0.45),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ===================== RADAR PAINTER =====================

class RadarPainter extends CustomPainter {
  final double sweepValue;
  final double pulseValue;
  final double dotFade;
  final bool itemFound;
  final double blipAngle;
  final double blipRadius;

  RadarPainter({
    required this.sweepValue,
    required this.pulseValue,
    required this.dotFade,
    required this.itemFound,
    required this.blipAngle,
    required this.blipRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 * 0.90;

    // Background
    canvas.drawCircle(
        center, maxRadius, Paint()..color = const Color(0xFF060C1A));

    // Concentric rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
        center,
        maxRadius * i / 4,
        Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Crosshairs
    final cross = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.07)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy), cross);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius), cross);

    // Diagonal lines
    final diag = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.04)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(center.dx - maxRadius * 0.7, center.dy - maxRadius * 0.7),
        Offset(center.dx + maxRadius * 0.7, center.dy + maxRadius * 0.7),
        diag);
    canvas.drawLine(
        Offset(center.dx + maxRadius * 0.7, center.dy - maxRadius * 0.7),
        Offset(center.dx - maxRadius * 0.7, center.dy + maxRadius * 0.7),
        diag);

    // Sweep arc
    final sweepAngle = sweepValue * 2 * pi - pi / 2;
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxRadius)));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle + pi / 2);

    final sweepRect =
        Rect.fromCircle(center: Offset.zero, radius: maxRadius);
    canvas.drawArc(
      sweepRect,
      -pi / 2,
      pi * 0.72,
      true,
      Paint()
        ..shader = SweepGradient(
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.0),
            const Color(0xFF00E5FF).withOpacity(0.0),
            const Color(0xFF00E5FF).withOpacity(0.25),
            const Color(0xFF00E5FF).withOpacity(0.55),
          ],
          stops: const [0.0, 0.55, 0.82, 1.0],
        ).createShader(sweepRect)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    // Leading edge line
    canvas.drawLine(
      center,
      Offset(center.dx + maxRadius * cos(sweepAngle),
          center.dy + maxRadius * sin(sweepAngle)),
      Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.9)
        ..strokeWidth = 1.5,
    );

    // Outer border
    canvas.drawCircle(
        center,
        maxRadius,
        Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Tick marks
    for (int i = 0; i < 36; i++) {
      final angle = i * pi / 18;
      final isMajor = i % 9 == 0;
      final innerR = maxRadius * (isMajor ? 0.92 : 0.96);
      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle),
            center.dy + innerR * sin(angle)),
        Offset(center.dx + maxRadius * cos(angle),
            center.dy + maxRadius * sin(angle)),
        Paint()
          ..color = const Color(0xFF00E5FF)
              .withOpacity(isMajor ? 0.35 : 0.12)
          ..strokeWidth = isMajor ? 1.5 : 0.8,
      );
    }

    // Center dot
    canvas.drawCircle(
        center, 5, Paint()..color = const Color(0xFF00E5FF));
    canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Pulse + blip when found
    if (itemFound) {
      for (int i = 0; i < 3; i++) {
        final t = (pulseValue + i * 0.33) % 1.0;
        canvas.drawCircle(
          center,
          maxRadius * 0.12 + maxRadius * 0.55 * t,
          Paint()
            ..color = const Color(0xFF00FF88).withOpacity((1 - t) * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      final bx = center.dx + maxRadius * blipRadius * cos(blipAngle);
      final by = center.dy + maxRadius * blipRadius * sin(blipAngle);
      final blipCenter = Offset(bx, by);

      canvas.drawCircle(blipCenter, 16,
          Paint()
            ..color =
                const Color(0xFF00FF88).withOpacity(0.12 * dotFade));
      canvas.drawCircle(blipCenter, 9,
          Paint()
            ..color =
                const Color(0xFF00FF88).withOpacity(0.28 * dotFade));
      canvas.drawCircle(blipCenter, 5,
          Paint()
            ..color = const Color(0xFF00FF88).withOpacity(dotFade));
      canvas.drawCircle(blipCenter, 2.5,
          Paint()..color = Colors.white.withOpacity(dotFade));
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) => true;
}