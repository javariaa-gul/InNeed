import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/storage_service.dart'; // Navigation logic from your code

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _collisionController;
  late AnimationController _dotController;
  late AnimationController _planeController;

  final List<double> _randomSeeds =
      List.generate(10, (index) => math.Random().nextDouble());

  @override
  void initState() {
    super.initState();

    // 1. Collision - The realistic chaotic impact
    _collisionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 2. Dot Drop - The final bounce finale
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 3. Plane flight - Screen Exit triggers Navigation
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Speed of planes crossing screen
    );

    // Ensure navigation triggers even if plane animation finishes
    // before the rest of the sequence completes (race condition).
    _planeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigate();
      }
    });

    _runAnimationSequence();
  }

  void _runAnimationSequence() async {
    // Start planes first
    _planeController.forward();

    await Future.delayed(const Duration(milliseconds: 300));

    // Start Collision course
    await _collisionController.forward();

    // Drop the 'i' dot after letters settle
    await Future.delayed(const Duration(milliseconds: 100));
    await _dotController.forward();

    // Wait for planes to fully leave the screen before navigating
    // Navigation is handled by the listener attached in initState.
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    // Check login status using your StorageService logic
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, loggedIn ? '/dashboard' : '/login');
  }

  @override
  void dispose() {
    _collisionController.dispose();
    _dotController.dispose();
    _planeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFD99),
      body: Stack(
        children: [
          // Premium Background Shades (White & Yellow)
          _buildEnhancedBackground(),

          // Planes flying through the screen
          Positioned(
              top: 100,
              child: PlaneTailWave(controller: _planeController, isTop: true)),
          Positioned(
              bottom: 150,
              child: PlaneTailWave(controller: _planeController, isTop: false)),

          // Main Animation Center
          Center(
            child: AnimatedBuilder(
              animation: _collisionController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWord("in", true, 0),
                    _buildWord("Need", false, 2),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWord(String word, bool isLeft, int startIndex) {
    double progress = _collisionController.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(word.length, (index) {
        double x = 0, y = 0, rotation = 0;
        double seed = _randomSeeds[startIndex + index];

        if (progress < 0.25) {
          double t = progress / 0.25;
          double accel = Curves.easeInCubic.transform(1 - t);
          x = isLeft ? -450 * accel : 450 * accel;
        } else {
          double t = (progress - 0.25) / 0.75;
          double elastic = Curves.elasticOut.transform(t);
          double angle = seed * 2 * math.pi;
          double force = 220 * (1 - elastic);

          x = math.cos(angle) * force;
          y = math.sin(angle) * force - (60 * (1 - elastic));
          rotation = (seed - 0.5) * 8 * (1 - elastic);
        }

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
              angle: rotation, child: _renderLetter(word[index])),
        );
      }),
    );
  }

  Widget _renderLetter(String char) {
    if (char == 'i') {
      return Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          const Text('ı', style: _textStyle),
          Positioned(
            top: -24,
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (context, child) {
                double drop = Curves.bounceOut.transform(_dotController.value);
                return Transform.translate(
                  offset: Offset(0, -500 * (1 - drop)),
                  child: Opacity(
                    opacity: _dotController.value > 0.05 ? 1 : 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.black, shape: BoxShape.circle),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return Text(char, style: _textStyle);
  }

  Widget _buildEnhancedBackground() {
    return Stack(
      children: [
        Positioned(
            top: -120,
            left: -60,
            child: _decor(380, Colors.white.withOpacity(0.4))),
        Positioned(
            bottom: 60,
            right: -120,
            child: _decor(420, const Color(0xFFF9F77E).withOpacity(0.5))),
        Positioned(
            top: 250,
            right: -50,
            child: _decor(200, Colors.white.withOpacity(0.25))),
        Positioned(
            bottom: -80,
            left: 30,
            child: _decor(280, const Color(0xFFF5F35D).withOpacity(0.4))),
      ],
    );
  }

  Widget _decor(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  static const _textStyle = TextStyle(
    fontSize: 98,
    fontWeight: FontWeight.w900,
    color: Colors.black,
    height: 1.0,
    letterSpacing: -4,
  );
}

class PlaneTailWave extends StatelessWidget {
  final AnimationController controller;
  final bool isTop;
  const PlaneTailWave(
      {super.key, required this.controller, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(MediaQuery.of(context).size.width, 140),
          painter: TailPainter(progress: controller.value, isTop: isTop),
        );
      },
    );
  }
}

class TailPainter extends CustomPainter {
  final double progress;
  final bool isTop;
  TailPainter({required this.progress, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Full screen entry to exit path
    double startX = isTop ? -100 : size.width + 100;
    double endX = isTop ? size.width + 100 : -100;

    path.moveTo(startX, 60);
    path.cubicTo(size.width * 0.3, isTop ? -70 : size.height + 70,
        size.width * 0.7, isTop ? size.height + 70 : -70, endX, 60);

    final metrics = path.computeMetrics().first;
    double currentLen = metrics.length * progress;
    canvas.drawPath(metrics.extractPath(0, currentLen), paint);

    final tangent = metrics.getTangentForOffset(currentLen);
    if (tangent != null) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(-tangent.angle);
      final p = Path();
      p.moveTo(18, 0);
      p.lineTo(-14, -11);
      p.lineTo(-8, 0);
      p.lineTo(-14, 11);
      p.close();
      canvas.drawPath(p, Paint()..color = Colors.black);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
