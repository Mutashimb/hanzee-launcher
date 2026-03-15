import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Import panel-panel yang baru dipisah
import 'panels/dashboard_panel.dart';
import 'panels/home_panel.dart';
import 'panels/app_list_panel.dart';

void main() => runApp(const HanZeeLauncher());

class HanZeeLauncher extends StatelessWidget {
  const HanZeeLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HanZee Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  static const platform = MethodChannel('com.example.hanzee/usage');
  
  Timer? _usageTimer;
  List<AppInfo> _installedApps = [];
  List<Map<String, dynamic>> _localTasks = [];
  Duration _todayScreenTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();    
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchRealScreenTime();
    });
  }

  Future<void> _loadData() async {
    await _loadTasks();
    await Future.wait([
      _preFetchApps(),
      _fetchRealScreenTime(),
    ]);
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // --- PERSISTENCE ---
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? tasksJson = prefs.getStringList('hanzee_tasks');
    if (mounted && tasksJson != null) {
      setState(() {
        _localTasks = tasksJson.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> tasksJson = _localTasks.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('hanzee_tasks', tasksJson);
  }

  void _updateTasks(List<Map<String, dynamic>> newTasks) {
    setState(() => _localTasks = newTasks);
    _saveTasks();
  }

  // --- LOGIC ---
  Future<void> _fetchRealScreenTime() async {
    try {
      final int minutes = await platform.invokeMethod('getTodayUsage');
      if (mounted) setState(() => _todayScreenTime = Duration(minutes: minutes));
    } on PlatformException catch (e) {
      debugPrint("Failed to get usage: ${e.message}");
    }
  }

  Future<void> _preFetchApps() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(excludeSystemApps: false, withIcon: false); 
      apps.sort((a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
      if (mounted) setState(() => _installedApps = apps);
    } catch (e) {
      debugPrint("Error fetching apps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          DashboardPanel(tasks: _localTasks, screenTime: _todayScreenTime, onTasksChanged: _updateTasks),
          HomePanel(screenTime: _todayScreenTime, taskCount: _localTasks.length),
          AppListPanel(apps: _installedApps),
        ],
      ),
    );
  }
}