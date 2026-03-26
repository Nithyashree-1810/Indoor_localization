import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const FindzApp());
}

class FindzApp extends StatelessWidget {
  const FindzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Findz',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  String proximityStatus = "Not Scanned Yet";
  bool scanning = false;
  final String espIP = "192.168.4.1";

  late AnimationController radarController;
  late AnimationController itemController;

  @override
  void initState() {
    super.initState();

    radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    // Item animation inside radar
    itemController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    radarController.dispose();
    itemController.dispose();
    super.dispose();
  }

  // ----------------------------
  //  Fetch RSSI
  // ----------------------------
  Future<void> scanProximity() async {
    setState(() => scanning = true);
    try {
      final response = await http.get(Uri.parse("http://$espIP/rssi"));
      if (response.statusCode == 200) {
        int rssi = int.tryParse(response.body.trim()) ?? -100;
        updateProximityBasedOnRSSI(rssi);
      } else {
        setState(() => proximityStatus = "Error reading RSSI");
      }
    } catch (e) {
      setState(() => proximityStatus = "ESP32 Not Connected");
    }
    setState(() => scanning = false);
  }

  void updateProximityBasedOnRSSI(int rssi) {
    if (rssi > -50) {
      proximityStatus = "Very Close 🔥 (RSSI: $rssi)";
      triggerBuzzerAndLED();
    } else if (rssi > -70) {
      proximityStatus = "Near 🙂 (RSSI: $rssi)";
    } else {
      proximityStatus = "Far 😢 (RSSI: $rssi)";
    }
    setState(() {});
  }

  Future<void> triggerBuzzerAndLED() async {
    try {
      await http.get(Uri.parse("http://$espIP/trigger"));
    } catch (_) {}
  }

  // ----------------------------
  //  UI Starts
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1B2A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Column(
          children: [
            const SizedBox(height: 60),

            // Centered Title
            Text(
              "Findz",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------
            //        Radar Widget
            // -------------------------
            SizedBox(
              width: 300,
              height: 300,
              child: AnimatedBuilder(
                animation: Listenable.merge([radarController, itemController]),
                builder: (_, __) {
                  return CustomPaint(
                    painter: RadarPainter(
                      radarController.value,
                      itemController.value,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Text(
              proximityStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 35),

            // SCAN BUTTON
            GestureDetector(
              onTap: scanning ? null : scanProximity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                decoration: BoxDecoration(
                  color: scanning ? Colors.red : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: scanning
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.blueAccent.withOpacity(0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Text(
                  scanning ? "Scanning..." : "Scan Item",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // BUZZER BUTTON
            ElevatedButton(
              onPressed: triggerBuzzerAndLED,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
              ),
              child: Text(
                "Trigger Buzzer + LED",
                style: GoogleFonts.poppins(
                    fontSize: 16, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// ------------------ RADAR PAINTER ------------------
//
class RadarPainter extends CustomPainter {
  final double radarValue;
  final double itemPulse;

  RadarPainter(this.radarValue, this.itemPulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 3 rings
    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // Sweep radar
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.tealAccent.withOpacity(0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
        transform: GradientRotation(pi * 2 * radarValue),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi * 2,
      true,
      Paint()..shader = sweepPaint,
    );

    // ------------------------------
    //   LOST ITEM DOT (Animated)
    // ------------------------------
    final double itemDistance = radius * 0.5; // middle ring
    final double itemAngle = radarValue * 2 * pi;

    final Offset itemPos = Offset(
      center.dx + itemDistance * cos(itemAngle),
      center.dy + itemDistance * sin(itemAngle),
    );

    final Paint itemPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.9);

    // Glow effect
    canvas.drawCircle(
      itemPos,
      12 + (itemPulse * 4),
      Paint()
        ..color = Colors.redAccent.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main dot
    canvas.drawCircle(itemPos, 8, itemPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => true;
}