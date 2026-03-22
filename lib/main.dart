import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'panels/dashboard_panel.dart';
import 'panels/home_panel.dart';
import 'panels/app_list_panel.dart';

void main() {
  // Optimasi: Memastikan binding diinisialisasi sebelum menjalankan app
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HanZeeLauncher());
}

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
        // Optimasi: Gunakan font display yang lebih efisien jika ada
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
  
  bool _isInitialLoading = true;
  Timer? _usageTimer;

  // OPTIMASI: Gunakan ValueNotifier untuk data yang sering berubah (Menghindari Global Rebuild)
  final ValueNotifier<Duration> _screenTimeNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Map<String, int>> _habitUsageNotifier = ValueNotifier({});
  
  List<AppInfo> _installedApps = [];
  List<Map<String, dynamic>> _localTasks = [];
  List<String> _watchedPackages = [];
  List<String> _quickApps = [];
  String _motivationText = "STAY FOCUSED";

  @override
  void initState() {
    super.initState();
    _loadData(); 

    // OPTIMASI: Gunakan timer yang lebih efisien
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchRealScreenTime();
      _fetchHabitsUsage(); 
    });
  }

  // OPTIMASI: Unfocus hanya saat halaman benar-benar berubah (bukan setiap pixel scroll)
  void _handlePageChange(int index) {
    if (index != 0) { // Jika bukan halaman dashboard/input, tutup keyboard
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> _loadData() async {
    // Tetap gunakan setState hanya untuk loading awal
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ambil data sekaligus untuk mengurangi await berkali-kali
      final tasksJson = prefs.getStringList('hanzee_tasks');
      _watchedPackages = prefs.getStringList('watched_apps') ?? [];
      _quickApps = prefs.getStringList('quick_apps') ?? [];
      _motivationText = prefs.getString('motivation_text') ?? "STAY FOCUSED";
      
      if (tasksJson != null) {
        _localTasks = tasksJson.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      }

      // Fetch apps di background
      await _preFetchApps();
      _fetchRealScreenTime();
      _fetchHabitsUsage();

    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  // --- LOGIC OPTIMIZED ---

  Future<void> _fetchRealScreenTime() async {
    try {
      final int minutes = await platform.invokeMethod('getTodayUsage');
      _screenTimeNotifier.value = Duration(minutes: minutes);
    } catch (_) {}
  }

  Future<void> _fetchHabitsUsage() async {
    if (_watchedPackages.isEmpty) return;
    
    Map<String, int> tempUsage = {};
    for (String pkg in _watchedPackages) {
      try {
        final int minutes = await platform.invokeMethod('getSpecificAppUsage', {'packageName': pkg});
        tempUsage[pkg] = minutes;
      } catch (_) {
        tempUsage[pkg] = 0;
      }
    }
    _habitUsageNotifier.value = tempUsage;
  }

  void _updateTasks(List<Map<String, dynamic>> newTasks) async {
    setState(() => _localTasks = newTasks);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hanzee_tasks', newTasks.map((e) => jsonEncode(e)).toList());
  }

  Future<void> _preFetchApps() async {
    try {
      // Optimasi: Fetch tanpa icon dulu agar cepat
      List<AppInfo> apps = await InstalledApps.getInstalledApps(excludeSystemApps: false, withIcon: false); 
      apps.sort((a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
      if (mounted) setState(() => _installedApps = apps);
    } catch (_) {}
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Penting: Scaffold di Main harus false agar DashboardPanel yang mengontrol insets
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onDoubleTap: () => platform.invokeMethod('lockScreen'),
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 10) {
            final x = details.globalPosition.dx;
            final width = MediaQuery.of(context).size.width;
            if (x < width / 2) {
              platform.invokeMethod('openNotifications');
            } else {
              platform.invokeMethod('openQuickSettings');
            }
          }
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: _handlePageChange, // OPTIMASI: Pengganti listener controller
          physics: const BouncingScrollPhysics(),
          children: [
            // Dashboard Panel
            ValueListenableBuilder(
              valueListenable: _screenTimeNotifier,
              builder: (context, screenTime, _) {
                return DashboardPanel(
                  tasks: _localTasks,
                  screenTime: screenTime,
                  onTasksChanged: _updateTasks,
                  watchedPackages: _watchedPackages,
                  allApps: _installedApps,
                  onToggleWatch: _toggleWatchApp,
                  quickApps: _quickApps,
                  onToggleQuickApp: _toggleQuickApp,
                  isInitialLoading: _isInitialLoading,
                );
              }
            ),

            // Home Panel
            ValueListenableBuilder(
              valueListenable: _screenTimeNotifier,
              builder: (context, screenTime, _) {
                return ValueListenableBuilder(
                  valueListenable: _habitUsageNotifier,
                  builder: (context, habitData, _) {
                    return HomePanel(
                      screenTime: screenTime,
                      taskCount: _localTasks.length,
                      watchedPackages: _watchedPackages,
                      habitUsageData: habitData,
                      allApps: _installedApps,
                      motivationText: _motivationText,
                      onUpdateMotivation: _updateMotivation,
                      quickApps: _quickApps,
                      isInitialLoading: _isInitialLoading,
                    );
                  }
                );
              }
            ),

            // App List Panel
            AppListPanel(
              apps: _installedApps,
              isInitialLoading: _isInitialLoading,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Functions (Tetap sama tapi gunakan SharedPreferences lokal)
  void _toggleQuickApp(String pkg) async {
    setState(() {
      _quickApps.contains(pkg) ? _quickApps.remove(pkg) : _quickApps.add(pkg);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('quick_apps', _quickApps);
  }

  void _toggleWatchApp(String pkg) async {
    setState(() {
      _watchedPackages.contains(pkg) ? _watchedPackages.remove(pkg) : _watchedPackages.add(pkg);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('watched_apps', _watchedPackages);
    _fetchHabitsUsage();
  }

  void _updateMotivation(String text) async {
    setState(() => _motivationText = text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('motivation_text', text);
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    _pageController.dispose();
    _screenTimeNotifier.dispose();
    _habitUsageNotifier.dispose();
    super.dispose();
  }
}