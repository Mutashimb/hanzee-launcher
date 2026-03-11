import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:sensors_plus/sensors_plus.dart';

enum KawaiiMood { happy, excited, surprised, thinking, sleepy }

class HanZeeFace extends StatefulWidget {
  final Duration screenTime;
  final int taskCount;

  const HanZeeFace({super.key, required this.screenTime, required this.taskCount});

  @override
  State<HanZeeFace> createState() => _HanZeeFaceState();
}

class _HanZeeFaceState extends State<HanZeeFace> with TickerProviderStateMixin {
  late AnimationController _moodController;
  late Animation<double> _moodAnimation;
  late AnimationController _idleController;
  
  bool _isBlinking = false;
  KawaiiMood _currentMood = KawaiiMood.happy;
  StreamSubscription? _accelSub;

  final Random _random = Random();
  double _jitterX = 0;
  double _jitterY = 0;
  
  Offset _lookAtOffset = Offset.zero;      
  Offset _idleLookOffset = Offset.zero;    
  Timer? _saccadeTimer;
  Timer? _idleLookTimer;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();

    _moodController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _moodAnimation = CurvedAnimation(
      parent: _moodController,
      curve: Curves.elasticOut, 
    );

    _startBlinkCycle();
    _startOrganicLogic();
    _resetSleepTimer();

    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      if (event.x.abs() > 30 || event.y.abs() > 30) {
        _setMood(KawaiiMood.excited, duration: const Duration(seconds: 3));
      }
    });
  }

  void _setMood(KawaiiMood mood, {Duration? duration}) {
    if (_currentMood == mood && mood != KawaiiMood.happy) return;
    setState(() => _currentMood = mood);
    _moodController.forward(from: 0.0);
    _resetSleepTimer();

    if (duration != null) {
      Future.delayed(duration, () {
        if (mounted && _currentMood == mood) _setMood(KawaiiMood.happy);
      });
    }
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _setMood(KawaiiMood.sleepy);
    });
  }

  void _startOrganicLogic() {
    _saccadeTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        setState(() {
          _jitterX = (_random.nextDouble() - 0.5) * 1.2;
          _jitterY = (_random.nextDouble() - 0.5) * 1.2;
        });
      }
    });

    _idleLookTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _lookAtOffset == Offset.zero && _currentMood == KawaiiMood.happy) {
        setState(() {
          _idleLookOffset = Offset((_random.nextDouble() - 0.5) * 15, (_random.nextDouble() - 0.5) * 6);
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _idleLookOffset = Offset.zero);
        });
      }
    });
  }

  void _handlePointer(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double dx = localPosition.dx - center.dx;
    double dy = localPosition.dy - center.dy;
    
    double maxLookDistance = 12.0; 
    double distance = sqrt(dx * dx + dy * dy);
    double multiplier = min(maxLookDistance, distance) / max(1, distance);

    setState(() {
      _lookAtOffset = Offset(dx * multiplier, dy * multiplier);
      _idleLookOffset = Offset.zero; 
    });
    if (_currentMood == KawaiiMood.sleepy) _setMood(KawaiiMood.happy);
    _resetSleepTimer();
  }

  void _startBlinkCycle() {
    Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) return;
      if (_currentMood == KawaiiMood.happy) {
        setState(() => _isBlinking = true);
        await Future.delayed(const Duration(milliseconds: 120));
        if (mounted) setState(() => _isBlinking = false);
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _saccadeTimer?.cancel();
    _idleLookTimer?.cancel();
    _sleepTimer?.cancel();
    _moodController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);
        return GestureDetector(
          onPanUpdate: (details) => _handlePointer(details.localPosition, size),
          onPanEnd: (_) => setState(() => _lookAtOffset = Offset.zero),
          onTapDown: (details) => _handlePointer(details.localPosition, size),
          onTapUp: (_) => setState(() => _lookAtOffset = Offset.zero),
          onDoubleTap: () => _setMood(KawaiiMood.surprised, duration: const Duration(seconds: 2)),
          onLongPress: () => _setMood(KawaiiMood.thinking, duration: const Duration(seconds: 4)),
          onTap: () => _setMood(KawaiiMood.happy),
          
          child: AnimatedBuilder(
            animation: Listenable.merge([_moodAnimation, _idleController]),
            builder: (context, child) {
              return CustomPaint(
                size: const Size(220, 160),
                painter: FluidKawaiiPainter(
                  mood: _currentMood,
                  moodProgress: _moodAnimation.value,
                  isBlinking: _isBlinking,
                  idleValue: _idleController.value,
                  jitterX: _jitterX,
                  jitterY: _jitterY,
                  lookAtOffset: _lookAtOffset == Offset.zero ? _idleLookOffset : _lookAtOffset,
                ),
              );
            },
          ),
        );
      }
    );
  }
}

class FluidKawaiiPainter extends CustomPainter {
  final KawaiiMood mood;
  final double moodProgress;
  final bool isBlinking;
  final double idleValue;
  final double jitterX;
  final double jitterY;
  final Offset lookAtOffset;

  FluidKawaiiPainter({
    required this.mood,
    required this.moodProgress, 
    required this.isBlinking,
    required this.idleValue,
    required this.jitterX,
    required this.jitterY,
    required this.lookAtOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final unit = min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final mainColor = Colors.white;

    final linePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.035 // Style tipis
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);

    double floatingY = cos(idleValue * 2 * pi) * 3.0;
    double eyeX = unit * 0.30;
    double eyeY = unit * 0.1;

    // 1. Pipi Glow (Menggunakan Path melingkar kustom)
    if (mood != KawaiiMood.sleepy) {
      _drawOrganicGlow(canvas, Offset(center.dx - eyeX, center.dy + unit * 0.25 + floatingY), unit * 0.06);
      _drawOrganicGlow(canvas, Offset(center.dx + eyeX, center.dy + unit * 0.25 + floatingY), unit * 0.06);
    }

    // 2. Gambar Mata (Pure Path)
    _drawPathEye(canvas, Offset(center.dx - eyeX + jitterX + lookAtOffset.dx, center.dy + eyeY + floatingY + jitterY + lookAtOffset.dy), unit, linePaint, true);
    _drawPathEye(canvas, Offset(center.dx + eyeX + (jitterX * 0.7) + lookAtOffset.dx, center.dy + eyeY + floatingY + (jitterY * 0.7) + lookAtOffset.dy), unit, linePaint, false);

    // 3. Gambar Mulut (Pure Path)
    _drawPathMouth(canvas, center.translate(0, floatingY * 0.5), unit, linePaint);
  }

  void _drawOrganicGlow(Canvas canvas, Offset pos, double radius) {
    final glowPath = Path();
    // Membuat lingkaran manual dengan 4 kurva Bezier agar terlihat lebih lembut
    glowPath.moveTo(pos.dx, pos.dy - radius);
    glowPath.quadraticBezierTo(pos.dx + radius, pos.dy - radius, pos.dx + radius, pos.dy);
    glowPath.quadraticBezierTo(pos.dx + radius, pos.dy + radius, pos.dx, pos.dy + radius);
    glowPath.quadraticBezierTo(pos.dx - radius, pos.dy + radius, pos.dx - radius, pos.dy);
    glowPath.quadraticBezierTo(pos.dx - radius, pos.dy - radius, pos.dx, pos.dy - radius);
    
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(glowPath, p);
  }

  void _drawPathEye(Canvas canvas, Offset pos, double unit, Paint stroke, bool isLeft) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    final path = Path();

    if (isBlinking && (mood == KawaiiMood.happy || mood == KawaiiMood.thinking)) {
      path.moveTo(-unit * 0.08, 0);
      path.quadraticBezierTo(0, unit * 0.01, unit * 0.08, 0);
      canvas.drawPath(path, stroke);
    } else {
      switch (mood) {
        case KawaiiMood.excited:
          double s = unit * 0.07 * moodProgress;
          double xSign = isLeft ? 1 : -1;
          path.moveTo(-s * xSign, -s);
          path.quadraticBezierTo(0, 0, s * xSign, 0); // Titik tajam di tengah
          path.quadraticBezierTo(0, 0, -s * xSign, s);
          canvas.drawPath(path, stroke);
          break;
          
        case KawaiiMood.surprised:
          double r = unit * 0.1 * moodProgress;
          // Membuat lingkaran kaget dengan Path
          path.moveTo(0, -r);
          path.quadraticBezierTo(r, -r, r, 0);
          path.quadraticBezierTo(r, r, 0, r);
          path.quadraticBezierTo(-r, r, -r, 0);
          path.quadraticBezierTo(-r, -r, 0, -r);
          canvas.drawPath(path, stroke);
          break;

        case KawaiiMood.thinking:
          double w = unit * (isLeft ? 0.08 : 0.12);
          double h = unit * (isLeft ? 0.04 : 0.15);
          path.moveTo(0, -h);
          path.quadraticBezierTo(w, -h, w, 0);
          path.quadraticBezierTo(w, h, 0, h);
          path.quadraticBezierTo(-w, h, -w, 0);
          path.quadraticBezierTo(-w, -h, 0, -h);
          canvas.drawPath(path, stroke);
          break;

        case KawaiiMood.sleepy:
          double w = unit * 0.08;
          path.moveTo(-w, 0);
          path.quadraticBezierTo(0, -unit * 0.05, w, 0);
          canvas.drawPath(path, stroke);
          break;

        default: // Happy / Normal (Oval kustom)
          double w = unit * 0.08;
          double h = unit * 0.12;
          path.moveTo(0, -h);
          path.quadraticBezierTo(w, -h, w, 0);
          path.quadraticBezierTo(w, h, 0, h);
          path.quadraticBezierTo(-w, h, -w, 0);
          path.quadraticBezierTo(-w, -h, 0, -h);
          canvas.drawPath(path, stroke);
      }
    }
    canvas.restore();
  }

  void _drawPathMouth(Canvas canvas, Offset center, double unit, Paint stroke) {
    double y = center.dy + unit * 0.35;
    final path = Path();

    switch (mood) {
      case KawaiiMood.surprised:
        double r = unit * 0.03 * moodProgress;
        path.moveTo(center.dx, y - r);
        path.quadraticBezierTo(center.dx + r, y - r, center.dx + r, y);
        path.quadraticBezierTo(center.dx + r, y + r, center.dx, y + r);
        path.quadraticBezierTo(center.dx - r, y + r, center.dx - r, y);
        path.quadraticBezierTo(center.dx - r, y - r, center.dx, y - r);
        canvas.drawPath(path, stroke);
        break;
      case KawaiiMood.thinking:
        path.moveTo(center.dx - unit * 0.04, y);
        path.quadraticBezierTo(center.dx, y, center.dx + unit * 0.04, y);
        canvas.drawPath(path, stroke);
        break;
      case KawaiiMood.sleepy:
        path.moveTo(center.dx - unit * 0.03, y + 3);
        path.quadraticBezierTo(center.dx, y - unit * 0.02, center.dx + unit * 0.03, y + 3);
        canvas.drawPath(path, stroke);
        break;
      default: // Happy
        double curve = unit * (0.03 + (0.02 * moodProgress));
        double w = unit * (0.05 + (0.01 * moodProgress));
        path.moveTo(center.dx - w, y);
        path.quadraticBezierTo(center.dx, y + curve, center.dx + w, y);
        canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant FluidKawaiiPainter oldDelegate) => true;
}