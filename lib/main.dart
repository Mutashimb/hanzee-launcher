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
  
  bool _isInitialLoading = true;
  Timer? _usageTimer;
  List<AppInfo> _installedApps = [];
  List<Map<String, dynamic>> _localTasks = [];
  Duration _todayScreenTime = Duration.zero;
  List<String> _watchedPackages = [];
  Map<String, int> _habitUsageData = {};
  String _motivationText = "STAY FOCUSED"; // Default value
  List<String> _quickApps = []; // Menyimpan package name aplikasi cepat
  

  @override
  void initState() {
    super.initState();
    _loadData(); 

    // --- POSISI YANG BENAR: DI DALAM initState ---
    
    // 1. Listener untuk menutup keyboard saat geser halaman
    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != 2) {
        FocusScope.of(context).unfocus();
      }
    });

    // 2. Timer untuk update screen time & habit dots setiap menit
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchRealScreenTime();
      _fetchHabitsUsage(); 
    });

    
  }

  Future<void> _loadData() async {
    setState(() => _isInitialLoading = true);

    try {
      await _loadTasks();
      await _preFetchApps(); // Tunggu daftar aplikasi selesai diambil...
      await _loadWatchedApps(); // ...baru load habit dan hitung durasinya.
      await _fetchRealScreenTime();
      await _loadMotivation();
      await _loadQuickApps();
    } catch (e) {
      debugPrint("Error during initial load: $e");
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }  
  }

  // Fungsi Load
  Future<void> _loadQuickApps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _quickApps = prefs.getStringList('quick_apps') ?? [];
    });
  }

  // Fungsi Toggle (Tambah/Hapus)
  void _toggleQuickApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_quickApps.contains(packageName)) {
        _quickApps.remove(packageName);
      } else if (_quickApps.length < 5) { // Batasi maksimal 5 aplikasi
        _quickApps.add(packageName);
      }
    });
    await prefs.setStringList('quick_apps', _quickApps);
  }

  // Fungsi untuk load teks
  Future<void> _loadMotivation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _motivationText = prefs.getString('motivation_text') ?? "STAY FOCUSED";
    });
  }

  // Fungsi untuk update & simpan teks
  void _updateMotivation(String newText) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _motivationText = newText;
    });
    await prefs.setString('motivation_text', newText);
  }

  Future<void> _loadWatchedApps() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _watchedPackages = prefs.getStringList('watched_apps') ?? [];
      });
      _fetchHabitsUsage();
    }
  }

  // Ambil durasi penggunaan dari Native
  Future<void> _fetchHabitsUsage() async {
    Map<String, int> tempUsage = {};
    for (String pkg in _watchedPackages) {
      try {
        final int minutes = await platform.invokeMethod('getSpecificAppUsage', {'packageName': pkg});
        tempUsage[pkg] = minutes;
      } catch (e) {
        tempUsage[pkg] = 0;
      }
    }
    if (mounted) {
      setState(() => _habitUsageData = tempUsage);
    }
  }

  // Fungsi Toggle (dipanggil dari Dashboard)
  void _toggleWatchApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_watchedPackages.contains(packageName)) {
        _watchedPackages.remove(packageName);
      } else {
        _watchedPackages.add(packageName);
      }
    });
    await prefs.setStringList('watched_apps', _watchedPackages);
    _fetchHabitsUsage(); 
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
  @override
Widget build(BuildContext context) {
  final double screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    resizeToAvoidBottomInset: false,
    body: GestureDetector(
      // PERBAIKAN: Hapus '=>' dan gunakan '{ }' saja
      onVerticalDragUpdate: (details) {
        // Cek jika gerakan ke bawah (delta positive)
        if (details.delta.dy > 10) {
          double xPosition = details.globalPosition.dx;
          
          if (xPosition < screenWidth / 2) {
            // SWIPE KIRI -> Notifikasi (Pastikan pakai 's' jika di Kotlin-nya 'openNotifications')
            platform.invokeMethod('openNotifications');
          } else {
            // SWIPE KANAN -> Quick Settings
            platform.invokeMethod('openQuickSettings');
          }
        }
      },
      child: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          DashboardPanel(
            tasks: _localTasks,
            screenTime: _todayScreenTime,
            onTasksChanged: _updateTasks,
            watchedPackages: _watchedPackages,
            allApps: _installedApps,
            onToggleWatch: _toggleWatchApp,
            quickApps: _quickApps,
            onToggleQuickApp: _toggleQuickApp,
            isInitialLoading: _isInitialLoading,
          ),
          HomePanel(
            screenTime: _todayScreenTime, 
            taskCount: _localTasks.length,
            watchedPackages: _watchedPackages,
            habitUsageData: _habitUsageData,
            allApps: _installedApps,
            motivationText: _motivationText,
            onUpdateMotivation: _updateMotivation,
            quickApps: _quickApps,
            isInitialLoading: _isInitialLoading,
          ),
          AppListPanel(
            apps: _installedApps,
            isInitialLoading: _isInitialLoading,
            ),
          ],
        ),
      ), // Akhir GestureDetector
    );
  }
}