import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'hanzee_face.dart';

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
          // Changed w200 to w400 for better presence
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
  
  // Initialize with an empty list; _loadTasks will fill it from storage
  List<Map<String, dynamic>> _localTasks = []; // Ubah tipe data
  Duration _todayScreenTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();        // Load saved tasks immediately    
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchRealScreenTime();
    });
  }

  // Menggabungkan loading data awal
  Future<void> _loadData() async {
    await _loadTasks();
    // Gunakan Future.wait untuk menjalankan task secara paralel
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

  // --- PERSISTENCE LOGIC ---
  
  Future<void> _loadTasks() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? tasksJson = prefs.getStringList('hanzee_tasks');
  if (mounted && tasksJson != null) {
    setState(() {
      _localTasks = tasksJson
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
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

  // --- SCREEN TIME LOGIC ---

  Future<void> _fetchRealScreenTime() async {
    try {
      final int minutes = await platform.invokeMethod('getTodayUsage');
      if (mounted) {
        setState(() {
          _todayScreenTime = Duration(minutes: minutes);
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get usage: ${e.message}");
    }
  }

  // --- APP LIST LOGIC ---

  Future<void> _preFetchApps() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false, 
        withIcon: false,
      ); 
      apps.sort((a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
      
      if (mounted) {
        setState(() {
          _installedApps = apps;
        });
      }
    } catch (e) {
      debugPrint("Error fetching apps: $e");
    }
  }

  // --- SINGLE BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          DashboardPanel(
            tasks: _localTasks,
            screenTime: _todayScreenTime,
            onTasksChanged: _updateTasks, // Pass the persistence helper here
          ),
          HomePanel(
            screenTime: _todayScreenTime, // Kirim data waktu layar
            taskCount: _localTasks.length, // Kirim jumlah tugas dari list
          ),
          AppListPanel(apps: _installedApps),
        ],
      ),
    );
  }
}

// --- PANEL 1: DASHBOARD (LOCAL FEATURES) ---
class DashboardPanel extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final Duration screenTime;
  final Function(List<Map<String, dynamic>>) onTasksChanged;

  const DashboardPanel({
    super.key,
    required this.tasks,
    required this.screenTime,
    required this.onTasksChanged,
  });

  @override
  State<DashboardPanel> createState() => _DashboardPanelState();
}

class _DashboardPanelState extends State<DashboardPanel> with AutomaticKeepAliveClientMixin {
  final TextEditingController _taskController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _addTask(String value) {
    if (value.trim().isNotEmpty) {
      final newTasks = List<Map<String, dynamic>>.from(widget.tasks)
        ..add({'title': value.trim(), 'description': ''});
      widget.onTasksChanged(newTasks);
      _taskController.clear();
    }
  }

  void _deleteTask(int index) {
    final newTasks = List<Map<String, dynamic>>.from(widget.tasks);
    newTasks.removeAt(index);
    widget.onTasksChanged(newTasks);
    HapticFeedback.mediumImpact();
  }

  void _editTask(int index, String newTitle, String newDesc) {
    final newTasks = List<Map<String, dynamic>>.from(widget.tasks);
    newTasks[index] = {'title': newTitle, 'description': newDesc};
    widget.onTasksChanged(newTasks);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Padding(
      padding: const EdgeInsets.only(left: 40.0, right: 40.0, top: 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 40),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("DIGITAL WELLBEING"),
                  // Perbaikan 1: Gunakan 'description' dan tambahkan callback kosong karena required
                  DashboardItem(
                    title: "${widget.screenTime.inHours}h ${widget.screenTime.inMinutes % 60}m",
                    description: "Total screen time today",
                    isAction: false,
                    onDelete: () {}, 
                    onEdit: (t, d) {},
                  ),
                  const SizedBox(height: 40),

                  _buildSectionHeader("FOCUS LIST"),
                  
                  TextField(
                    controller: _taskController,
                    onSubmitted: _addTask,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                    decoration: const InputDecoration(
                      hintText: "add a task...",
                      hintStyle: TextStyle(color: Colors.white10),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (widget.tasks.isEmpty) 
                    const Text("No tasks for today.", style: TextStyle(color: Colors.white38))
                  else
                    ...widget.tasks.asMap().entries.map((entry) {
                      int index = entry.key;
                      
                      // 1. Ambil data Map-nya dulu
                      Map<String, dynamic> task = entry.value; 

                      return DashboardItem(
                        // 2. Ambil isi 'title' dari Map, bukan entry.value langsung
                        title: task['title'] ?? 'No Title', 
                        
                        // 3. Ambil isi 'description' dari Map
                        description: task['description'] ?? '', 
                        
                        isAction: true,
                        onDelete: () => _deleteTask(index),
                        
                        // 4. Pastikan onEdit menerima dua data (judul & deskripsi)
                        onEdit: (newTitle, newDesc) => _editTask(index, newTitle, newDesc),
                      );
                    }),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper UI tetap sama
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("DASHBOARD", style: TextStyle(letterSpacing: 4, color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(DateFormat('MMMM d').format(DateTime.now()).toUpperCase(), 
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
    );
  }
}

class DashboardItem extends StatefulWidget {
  final String title;
  final String description; // Menggantikan subtitle
  final bool isAction;
  final VoidCallback onDelete;
  final Function(String, String) onEdit;

  const DashboardItem({
    super.key, 
    required this.title, 
    required this.description, 
    required this.isAction,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<DashboardItem> createState() => _DashboardItemState();
}

class _DashboardItemState extends State<DashboardItem> {
  bool _isExpanded = false;

  void _showEditSheet(BuildContext context) {
    if (!widget.isAction) return;
    
    final titleController = TextEditingController(text: widget.title);
    final descController = TextEditingController(text: widget.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 30, right: 30, top: 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("EDIT TASK", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(hintText: "Title", border: InputBorder.none),
              autofocus: true,
            ),
            TextField(
              controller: descController,
              maxLines: null,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w300),
              decoration: const InputDecoration(hintText: "Add description...", border: InputBorder.none),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                  child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () {
                    widget.onEdit(titleController.text, descController.text);
                    Navigator.pop(context);
                  },
                  child: const Text("SAVE", style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (widget.description.isNotEmpty) {
          setState(() => _isExpanded = !_isExpanded);
        }
      },
      onLongPress: () => _showEditSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 2, height: 40, color: widget.isAction ? Colors.white : Colors.white10),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    widget.title, 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)
                  ),
                  if (_isExpanded && widget.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        widget.description, 
                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w300)
                      ),
                    ),
                  if (!_isExpanded && widget.description.isNotEmpty && widget.isAction)
                    const Text("tap to see description...", style: TextStyle(color: Colors.white10, fontSize: 10)),
                  if (!widget.isAction) // Untuk Digital Wellbeing subtitle tetap muncul
                     Text(widget.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]
              ),
            ),
            if (widget.isAction)
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white10, size: 20),
                onPressed: () => _showEditSheet(context),
              ),
          ],
        ),
      ),
    );
  }
}

// --- PANEL 2: HOME ---
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
          // --- 1. WAJAH SEKARANG DI PALING ATAS ---
          HanZeeFace(
            screenTime: screenTime,
            taskCount: taskCount,
          ),
          
          const SizedBox(height: 30), // Beri jarak sedikit

          // --- 2. INDIKATOR BATERAI DI BAWAH WAJAH ---
          FutureBuilder<int>(
            future: battery.batteryLevel,
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData ? "${snapshot.data}%" : "--%",
                style: const TextStyle(
                  color: Colors.white30, 
                  fontSize: 14, 
                  letterSpacing: 2,
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),

          // --- 3. JAM DIGITAL ---
          const DigitalClock(),

          const SizedBox(height: 60),

          // --- 4. PESAN MOTIVASI ---
          const Text(
            "STAY FOCUSED.", 
            style: TextStyle(
              color: Colors.white24, 
              fontSize: 12, 
              letterSpacing: 8,
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
    // Update widget ini setiap 1 detik
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Pastikan timer dimatikan saat tidak digunakan
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String timeString = DateFormat('HH:mm').format(now);
    final String dateString = DateFormat('EEEE, MMMM d').format(now).toUpperCase();

    return Column(
      children: [
        Text(
          timeString,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 90,
            fontWeight: FontWeight.w400, // Menggunakan w400 sesuai keinginanmu sebelumnya
            letterSpacing: -2,
          ),
        ),
        Text(
          dateString,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


// --- PANEL 3: APP LIST (WITH SEARCH & SLIDE BAR) ---
// PANEL 3: APP LIST (WITH ANIMATED CURVED SIDEBAR)
// --- PANEL 3: APP LIST (OPTIMIZED) ---
// --- PANEL 3: APP LIST (FIXED ALIGNMENT & WIDER TOUCH AREA) ---
class AppListPanel extends StatefulWidget {
  final List<AppInfo> apps;
  const AppListPanel({super.key, required this.apps});

  @override
  State<AppListPanel> createState() => _AppListPanelState();
}

class _AppListPanelState extends State<AppListPanel> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<AppInfo> _filteredApps = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Inisialisasi awal dengan data yang ada
    _filteredApps = widget.apps;
  }

  // --- SOLUSI LIST KOSONG: didUpdateWidget ---
  @override
  void didUpdateWidget(AppListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika daftar aplikasi dari sistem (parent) berubah/selesai di-load
    if (widget.apps != oldWidget.apps || (_filteredApps.isEmpty && widget.apps.isNotEmpty)) {
      setState(() {
        // Jika tidak sedang mencari, tampilkan semua aplikasi yang baru masuk
        if (_searchController.text.isEmpty) {
          _filteredApps = widget.apps;
        } else {
          // Jika sedang mencari, filter ulang data yang baru masuk tersebut
          _filterApps(_searchController.text);
        }
      });
    }
  }

  void _filterApps(String query) {
    setState(() {
      _filteredApps = widget.apps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _scrollToLetter(String letter) {
    if (_filteredApps.isEmpty) return;
    int index = _filteredApps.indexWhere(
      (app) => app.name.toUpperCase().startsWith(letter)
    );
    if (index != -1) {
      _scrollController.jumpTo(index * 52.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              // Beri ruang di kanan (right: 60) agar list tidak tertutup sidebar
              padding: const EdgeInsets.only(left: 40.0, top: 80.0, bottom: 40.0, right: 60.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("APPS", style: TextStyle(letterSpacing: 4, color: Colors.white54, fontSize: 10)),
                  TextField(
                    controller: _searchController,
                    onChanged: _filterApps,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400),
                    decoration: const InputDecoration(
                      hintText: "search",
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _filteredApps.isEmpty 
                      ? const Center(child: Text("No apps found", style: TextStyle(color: Colors.white24)))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredApps.length,
                          itemExtent: 52.0,
                          padding: EdgeInsets.zero, 
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) => AppListItem(app: _filteredApps[index]),
                        ),
                  ),
                ],
              ),
            ),
          ),

          // --- SIDEBAR DENGAN LEBAR YANG DIKALIBRASI ---
          Positioned(
            right: 0, 
            top: 120, 
            bottom: 60, 
            width: 80, // DIKECILKAN: Dari 120 ke 80 agar tidak mudah tersentuh tidak sengaja
            child: AlphabetSidebar(
              onLetterSelected: _scrollToLetter,
            ),
          ),
        ],
      ),
    );
  }
}

class AlphabetSidebar extends StatefulWidget {
  final Function(String) onLetterSelected;
  const AlphabetSidebar({super.key, required this.onLetterSelected});

  @override
  State<AlphabetSidebar> createState() => _AlphabetSidebarState();
}

class _AlphabetSidebarState extends State<AlphabetSidebar> {
  final List<String> _alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  double _touchY = 0.0;
  bool _isDragging = false;
  String _lastLetter = "";

  void _handleUpdate(Offset localPos, double maxHeight) {
    final double itemHeight = maxHeight / _alphabet.length;
    int index = (localPos.dy / itemHeight).floor().clamp(0, _alphabet.length - 1);
    
    String currentLetter = _alphabet[index];
    if (currentLetter != _lastLetter) {
      _lastLetter = currentLetter;
      widget.onLetterSelected(currentLetter);
      HapticFeedback.selectionClick(); 
    }

    setState(() {
      _touchY = localPos.dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxHeight = constraints.maxHeight;
      final double itemHeight = maxHeight / _alphabet.length;

      return GestureDetector(
        behavior: HitTestBehavior.opaque, 
        onVerticalDragStart: (details) {
          setState(() => _isDragging = true);
          _handleUpdate(details.localPosition, maxHeight);
        },
        onVerticalDragUpdate: (details) => _handleUpdate(details.localPosition, maxHeight),
        onVerticalDragEnd: (_) => setState(() {
          _isDragging = false;
          _lastLetter = "";
        }),
        child: Stack(
          alignment: Alignment.centerRight,
          clipBehavior: Clip.none,
          children: [
            ...List.generate(_alphabet.length, (i) {
              double factor = 0.0;
              if (_isDragging) {
                double letterY = i * itemHeight + (itemHeight / 2);
                double dist = (_touchY - letterY).abs();
                if (dist < 150) {
                  factor = pow(1 - (dist / 150), 3).toDouble();
                }
              }

              return Positioned(
                top: i * itemHeight,
                // Tetap dorong jauh ke kiri agar kelihatan dari balik jari
                right: 15 + (80 * factor), 
                child: IgnorePointer(
                  child: Text(
                    _alphabet[i],
                    style: TextStyle(
                      fontSize: 10 + (25 * factor), 
                      color: factor > 0.2 ? Colors.white : Colors.white24,
                      fontWeight: factor > 0.2 ? FontWeight.w900 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),

            // Floating Indicator tetap di posisi 120 (di luar area sensor 80)
            if (_isDragging && _lastLetter.isNotEmpty)
              Positioned(
                top: _touchY - 60,
                right: 100, // Disesuaikan agar tetap terlihat jelas
                child: Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    _lastLetter,
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class AppListItem extends StatelessWidget {
  final AppInfo app;
  const AppListItem({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => InstalledApps.startApp(app.packageName),
      child: Container(
        height: 52, // Sesuaikan dengan itemExtent
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(width: 2, height: 20, color: Colors.white10),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                app.name.toLowerCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}