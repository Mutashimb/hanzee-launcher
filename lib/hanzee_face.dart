import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

enum KawaiiMood { happy, excited, surprised, thinking, sleepy }

class HanZeeFace extends StatefulWidget {
  final Duration screenTime;
  final int taskCount;

  const HanZeeFace({super.key, required this.screenTime, required this.taskCount});

  @override
  State<HanZeeFace> createState() => _HanZeeFaceState();
}

class _HanZeeFaceState extends State<HanZeeFace> with TickerProviderStateMixin {
  late AnimationController _idleController;
  
  bool _isBlinking = false;
  KawaiiMood _currentMood = KawaiiMood.happy;
  StreamSubscription? _accelSub;

  final Random _random = Random();
  double _jitterX = 0;
  double _jitterY = 0;
     
  Offset _targetLookOffset = Offset.zero;    
  Timer? _saccadeTimer;
  Timer? _idleLookTimer;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _startBlinkCycle();
    _startOrganicLogic();
    _resetSleepTimer();
  }

  void _setMood(KawaiiMood mood, {Duration? duration}) {
    if (_currentMood == mood && mood != KawaiiMood.happy) return;
    setState(() => _currentMood = mood);
    _resetSleepTimer();

    if (duration != null) {
      Future.delayed(duration, () {
        if (mounted && _currentMood == mood) _setMood(KawaiiMood.happy);
      });
    }
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) _setMood(KawaiiMood.sleepy);
    });
  }

  void _startOrganicLogic() {
    // Saccade: Gerakan mata kecil yang tidak teratur agar terlihat hidup
    _saccadeTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _jitterX = (_random.nextDouble() - 0.5) * 2.0;
          _jitterY = (_random.nextDouble() - 0.5) * 2.0;
        });
      }
    });

    _idleLookTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _targetLookOffset == Offset.zero && _currentMood == KawaiiMood.happy) {
        setState(() {
          _targetLookOffset = Offset((_random.nextDouble() - 0.5) * 20, (_random.nextDouble() - 0.5) * 10);
        });
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) setState(() => _targetLookOffset = Offset.zero);
        });
      }
    });
  }

  void _handlePointer(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double dx = localPosition.dx - center.dx;
    double dy = localPosition.dy - center.dy;
    
    double maxLookDistance = 15.0; 
    double distance = sqrt(dx * dx + dy * dy);
    double multiplier = min(maxLookDistance, distance) / max(1, distance);

    setState(() {
      _targetLookOffset = Offset(dx * multiplier, dy * multiplier);
    });
    if (_currentMood == KawaiiMood.sleepy) _setMood(KawaiiMood.happy);
    _resetSleepTimer();
  }

  void _startBlinkCycle() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) return;
      if (_currentMood != KawaiiMood.sleepy) {
        setState(() => _isBlinking = true);
        await Future.delayed(const Duration(milliseconds: 150));
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
          onPanEnd: (_) => setState(() => _targetLookOffset = Offset.zero),
          onTapDown: (details) => _handlePointer(details.localPosition, size),
          onTapUp: (_) => setState(() => _targetLookOffset = Offset.zero),
          onDoubleTap: () => _setMood(KawaiiMood.surprised, duration: const Duration(seconds: 2)),
          onLongPress: () => _setMood(KawaiiMood.thinking, duration: const Duration(seconds: 4)),
          onTap: () => _setMood(KawaiiMood.happy),
          
          // Menggunakan TweenAnimationBuilder untuk transisi gerakan mata yang super halus
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(begin: Offset.zero, end: _targetLookOffset),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animatedOffset, child) {
              return AnimatedBuilder(
                animation: _idleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(220, 160),
                    painter: CuteKawaiiPainter(
                      mood: _currentMood,
                      isBlinking: _isBlinking,
                      idleValue: _idleController.value,
                      jitterX: _jitterX,
                      jitterY: _jitterY,
                      lookAtOffset: animatedOffset,
                    ),
                  );
                },
              );
            },
          ),
        );
      }
    );
  }
}

class CuteKawaiiPainter extends CustomPainter {
  final KawaiiMood mood;
  final bool isBlinking;
  final double idleValue;
  final double jitterX;
  final double jitterY;
  final Offset lookAtOffset;

  CuteKawaiiPainter({
    required this.mood,
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
    
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double floatingY = sin(idleValue * 2 * pi) * 3.0;
    double eyeSpacing = unit * 0.25;
    double eyeY = center.dy + floatingY;

    bool isSleepy = mood == KawaiiMood.sleepy;
    double finalJitterX = isSleepy ? 0 : jitterX;
    double finalJitterY = isSleepy ? 0 : jitterY;
    Offset finalLookOffset = isSleepy ? Offset.zero : lookAtOffset;

    // 1. Draw Soft Blush (Pipi)
    if (mood != KawaiiMood.sleepy) {
      _drawSoftCheek(canvas, Offset(center.dx - eyeSpacing + unit * 0.05 , eyeY + unit * 0.1), unit * 0.13);
      _drawSoftCheek(canvas, Offset(center.dx + eyeSpacing - unit * 0.05, eyeY + unit * 0.1), unit * 0.13);
    }

       // 2. Draw Eyes with Glass Effect
    _drawGlassyEye(
       canvas, 
      Offset(center.dx - eyeSpacing + finalJitterX + finalLookOffset.dx, eyeY + finalJitterY + finalLookOffset.dy), 
      unit, 
      linePaint, 
      
    );
    _drawGlassyEye(
      canvas, 
      Offset(center.dx + eyeSpacing + finalJitterX + finalLookOffset.dx, eyeY + finalJitterY + finalLookOffset.dy), 
      unit, 
      linePaint, 
   
    );

    // 3. Draw Mouth
    _drawCuteMouth(canvas, center.translate(0, floatingY), unit, linePaint);
  }

  void _drawSoftCheek(Canvas canvas, Offset pos, double radius) {
    final cheekPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.pinkAccent.withValues(alpha: 0.3),
          Colors.pinkAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: radius));
    
    canvas.drawCircle(pos, radius, cheekPaint);
  }

  void _drawGlassyEye(Canvas canvas, Offset pos, double unit, Paint stroke) {
    if (isBlinking && mood != KawaiiMood.excited) {
      // Kelopak mata saat berkedip
      final blinkPath = Path();
      blinkPath.moveTo(pos.dx - unit * 0.05, pos.dy);
      blinkPath.quadraticBezierTo(pos.dx, pos.dy + unit * 0.02, pos.dx + unit * 0.05, pos.dy);
      canvas.drawPath(blinkPath, stroke);
      return;
    }

    if (mood == KawaiiMood.sleepy) {
      // Mata setengah tertutup untuk mood sleepy
      final sleepyPath = Path();
      sleepyPath.moveTo(pos.dx - unit * 0.05, pos.dy);
      sleepyPath.quadraticBezierTo(pos.dx, pos.dy + unit * 0.04, pos.dx + unit * 0.05, pos.dy);
      canvas.drawPath(sleepyPath, stroke);
      return;
    }

    if (mood == KawaiiMood.surprised) {
      // Mata lebih besar untuk mood surprised
      final surprisedPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02;
      canvas.drawCircle(pos, unit * 0.08, surprisedPaint);
    }


    double eyeSize = unit * 0.08;
    
    // Base Eye (Pupil gelap dengan gradasi)
    final pupilPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2D2D2D),
          const Color(0xFF000000),
        ],
        center: const Alignment(0.2, -0.2),
      ).createShader(Rect.fromCircle(center: pos, radius: eyeSize));

    canvas.drawCircle(pos, eyeSize, pupilPaint);

    // Glass Effect Layer 1 (Pantulan cahaya bawah yang halus)
    final bottomReflection = Paint()
      ..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawArc(
      Rect.fromCircle(center: pos, radius: eyeSize * 0.8),
      0.2, 
      pi * 0.8, 
      false, 
      bottomReflection
    );

    // Glass Effect Layer 2 (Highlight utama/kaca)
    final mainHighlight = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(
      pos.translate(-eyeSize * 0.1 , -eyeSize * 0.1), 
      eyeSize * 0.3, 
      mainHighlight
    );

    // Glass Effect Layer 3 (Highlight sekunder kecil)
    canvas.drawCircle(
      pos.translate(eyeSize * 0.4, eyeSize * 0.2), 
      eyeSize * 0.12, 
      Paint()..color = Colors.white.withValues(alpha: 0.4)
    );
  }

  void _drawCuteMouth(Canvas canvas, Offset center, double unit, Paint stroke) {
    double y = center.dy + unit * 0.18;
    final path = Path();

    if (mood == KawaiiMood.surprised) {
      canvas.drawCircle(Offset(center.dx, y), unit * 0.03, stroke);
    } else if (mood == KawaiiMood.sleepy) {
      path.moveTo(center.dx - unit * 0.03, y + unit * 0.02);
      path.quadraticBezierTo(center.dx, y, center.dx + unit * 0.03, y + unit * 0.02);
      canvas.drawPath(path, stroke);
    } else {
      // Small cat mouth (w)
      double w = unit * 0.05;
      path.moveTo(center.dx - w, y);
      // path.quadraticBezierTo(center.dx - w/2, y + unit * 0.03, center.dx, y);
      path.quadraticBezierTo(center.dx + w/8, y + unit * 0.03, center.dx + w, y);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CuteKawaiiPainter oldDelegate) => true;
}