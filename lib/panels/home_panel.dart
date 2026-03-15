import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../hanzee_face.dart';

class HomePanel extends StatelessWidget {
  final Duration screenTime;
  final int taskCount;

  const HomePanel({
    super.key,
    required this.screenTime,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    final Battery battery = Battery();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HanZeeFace(screenTime: screenTime, taskCount: taskCount),
          const SizedBox(height: 30),
          FutureBuilder<int>(
            future: battery.batteryLevel,
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData ? "${snapshot.data}%" : "--%",
                style: const TextStyle(color: Colors.white30, fontSize: 14, letterSpacing: 2),
              );
            },
          ),
          const SizedBox(height: 40),
          const DigitalClock(),
          const SizedBox(height: 60),
          const Text(
            "STAY FOCUSED.",
            style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w500, fontSize: 12, letterSpacing: 8),
          ),
        ],
      ),
    );
  }
}

class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key});

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return Column(
      children: [
        Text(DateFormat('HH:mm').format(now),
          style: const TextStyle(color: Colors.white, fontSize: 90, fontWeight: FontWeight.w400, letterSpacing: -2),
        ),
        Text(DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}