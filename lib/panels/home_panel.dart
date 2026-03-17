import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../hanzee_face.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart'; // Tambahkan ini

class HomePanel extends StatelessWidget {
  final Duration screenTime;
  final int taskCount;
  final List<String> watchedPackages;
  final Map<String, int> habitUsageData;
  final List<AppInfo> allApps;
  final String motivationText;
  final Function(String) onUpdateMotivation;
  final List<String> quickApps;

  const HomePanel({
    super.key,
    required this.screenTime,
    required this.taskCount,
    required this.watchedPackages,
    required this.habitUsageData,
    required this.allApps,
    required this.motivationText, // Masukkan ke constructor
    required this.onUpdateMotivation,
    required this.quickApps,
  });

  void _showEditMotivation(BuildContext context) {
    final controller = TextEditingController(text: motivationText);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          left: 30, right: 30, top: 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SET MOTIVATION", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "Enter text..."),
              onSubmitted: (val) {
                onUpdateMotivation(val);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Battery battery = Battery();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HanZeeFace(screenTime: screenTime, taskCount: taskCount),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: watchedPackages.map((pkg) {
              // 1. CEK: Jika list aplikasi masih kosong, tampilkan placeholder saja
                if (allApps.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(width: 10, height: 10), // Kosongkan dulu
                  );
                }

                // 2. CARI APP: Pakai try-catch atau filter yang aman
                final app = allApps.firstWhere(
                  (a) => a.packageName == pkg,
                  // FIX: Jangan pakai allApps.first jika ada risiko kosong
                  orElse: () => AppInfo(
                    name: "...",
                    packageName: pkg,
                    icon: null,
                    versionName: "",
                    versionCode: 0,
                    platformType: PlatformType.flutter,
                    installedTimestamp: 0,
                    isSystemApp: false,
                    isLaunchableApp: true,
                    category: AppCategory.undefined,
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: HabitDot(
                    appName: app.name,
                    usageMinutes: habitUsageData[pkg] ?? 0,
                  ),
                );
              }).toList(),
          ),

        const SizedBox(height: 40),

        // --- DIGITAL WELLBEING (PINDAHAN) ---
        // Ditampilkan kecil dan elegan
        Text(
          "${screenTime.inHours}H ${screenTime.inMinutes % 60}M",
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 16, 
            letterSpacing: 2,
            fontWeight: FontWeight.w500
          ),
        ),
        const Text(
          "SCREEN TIME",
          style: TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 2),
        ),

        const SizedBox(height: 20),


          FutureBuilder<int>(
            future: battery.batteryLevel,
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData ? "${snapshot.data}%" : "--%",
                style: const TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2),
              );
            },
          ),
          const SizedBox(height: 40),
          const DigitalClock(),
          const SizedBox(height: 40),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20, // Jarak antar nama aplikasi
            children: quickApps.map((pkg) {
              if (allApps.isEmpty) return const SizedBox();
              final app = allApps.firstWhere((a) => a.packageName == pkg, 
                orElse: () => allApps.first);

              return InkWell(
                onTap: () => InstalledApps.startApp(pkg),
                child: Text(
                  app.name.toLowerCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),
          const SizedBox(height: 60),
          InkWell(
            onLongPress: () => _showEditMotivation(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                motivationText.isEmpty ? "SET MOTIVATION" : motivationText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54, 
                  fontWeight: FontWeight.w700, 
                  fontSize: 12, 
                  letterSpacing: 8
                ),
              ),
            ),
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

class HabitDot extends StatelessWidget {
  final String appName;
  final int usageMinutes;
  final int goalMinutes;

  const HabitDot({
    super.key,
    required this.appName,
    required this.usageMinutes,
    this.goalMinutes = 5,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (usageMinutes / goalMinutes).clamp(0.0, 1.0);
    // Sekarang isFinished berarti "Sudah Aman", maka tandanya harus MATI/REDUP
    bool isFinished = progress >= 1.0; 

    return Tooltip(
      message: isFinished ? "$appName: Done" : "$appName: ${goalMinutes - usageMinutes} min left",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // TERBALIK: Jika sudah selesai (isFinished), buat jadi transparan/redup
              // Jika belum selesai, buat menyala (Colors.white)
              color: isFinished ? Colors.transparent : Colors.white,
              border: Border.all(
                color: isFinished ? Colors.white10 : Colors.white,
                width: 1.5,
              ),
              boxShadow: !isFinished ? [
                // Glow/bayangan hanya muncul saat BELUM selesai (sebagai pengingat)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ] : [],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appName.isNotEmpty ? appName[0].toUpperCase() : "?",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              // Teks juga meredup jika sudah selesai
              color: isFinished ? Colors.white10 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}