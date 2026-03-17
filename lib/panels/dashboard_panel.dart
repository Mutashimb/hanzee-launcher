import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:intl/intl.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class DashboardPanel extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final Duration screenTime;
  final Function(List<Map<String, dynamic>>) onTasksChanged;
  
  final List<String> watchedPackages;
  final List<AppInfo> allApps;
  final Function(String) onToggleWatch;
  final List<String> quickApps; // Tambahkan ini
  final Function(String) onToggleQuickApp; // Tambahkan ini

  const DashboardPanel({
    super.key,
    required this.tasks,
    required this.screenTime,
    required this.onTasksChanged,
    required this.watchedPackages,
    required this.allApps,
    required this.onToggleWatch,
    required this.quickApps, // Tambahkan ini
    required this.onToggleQuickApp, // Tambahkan ini
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

  // --- LOGIKA TASK ---
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


  // Dialog Pemilih Aplikasi yang diperbarui (Generic)
  void _showAppSelector({required bool isHabit}) {
  // Kita buat list lokal untuk menampung hasil filter
  List<AppInfo> filteredApps = widget.allApps;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => StatefulBuilder( // Tambahkan StatefulBuilder agar UI modal bisa update
      builder: (context, setModalState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              // HEADER TEXT
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Text(
                  isHabit ? "SELECT HABIT APP" : "SELECT QUICK ACCESS APP",
                  style: const TextStyle(
                    letterSpacing: 2, 
                    color: Colors.white38, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),

              // --- SEARCH BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    autofocus: false,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (value) {
                      // Logika pencarian aplikasi
                      setModalState(() {
                        filteredApps = widget.allApps
                            .where((app) => app.name
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: "Search apps...",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.white24, size: 20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // LIST APLIKASI
              Expanded(
                child: filteredApps.isEmpty
                    ? const Center(
                        child: Text("No apps found", 
                        style: TextStyle(color: Colors.white24)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final bool isSelected = isHabit
                              ? widget.watchedPackages.contains(app.packageName)
                              : widget.quickApps.contains(app.packageName);

                          return ListTile(
                            leading: Container(
                              width: 2, 
                              height: 20, 
                              color: isSelected ? Colors.white : Colors.white10
                            ),
                            title: Text(
                              app.name.toLowerCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                            onTap: () {
                              if (isHabit) {
                                widget.onToggleWatch(app.packageName);
                              } else {
                                widget.onToggleQuickApp(app.packageName);
                              }
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
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
                  _buildSectionHeader("DAILY HABITS"),
                  if (widget.watchedPackages.isEmpty)
                    const Text("No apps on watchlist.", style: TextStyle(color: Colors.white24, fontSize: 24))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.watchedPackages.map((pkg) {
                        if (widget.allApps.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: const Text("loading...", style: TextStyle(color: Colors.white10)),
                          );
                        }
                        // FIX: Memberikan nilai default lengkap untuk AppInfo jika tidak ditemukan
                        final app = widget.allApps.firstWhere(
                          (a) => a.packageName == pkg,
                          orElse: () => AppInfo(
                            name: "unknown",
                            icon: null,
                            packageName: pkg,
                            versionName: "1.0",
                            versionCode: 1,
                            platformType: PlatformType.flutter,
                            installedTimestamp: 0,
                            isSystemApp: false,
                            isLaunchableApp: true,
                            category: AppCategory.undefined,
                          ),
                        );
                        
                        return GestureDetector(
                          onLongPress: () {
                            widget.onToggleWatch(pkg);
                            HapticFeedback.heavyImpact();
                          },
                          onTap: () => InstalledApps.startApp(pkg),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              app.name.toLowerCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  TextButton.icon(
                    onPressed: () => _showAppSelector(isHabit: true),
                    icon: const Icon(Icons.add, size: 14, color: Colors.white24),
                    label: const Text("add reminder", style: TextStyle(color: Colors.white30, fontSize: 16)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 40),

                  _buildSectionHeader("QUICK ACCESS"),
                  if (widget.quickApps.isEmpty)
                    const Text("No quick apps set.", style: TextStyle(color: Colors.white10, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      children: widget.quickApps.map((pkg) {
                        final app = widget.allApps.firstWhere((a) => a.packageName == pkg, orElse: () => widget.allApps.first);
                        return Chip(
                          label: Text(app.name.toLowerCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.white10,
                          onDeleted: () => widget.onToggleQuickApp(pkg), // Hapus lewat tanda silang
                          deleteIconColor: Colors.white38,
                        );
                      }).toList(),
                    ),
                  TextButton(
                    onPressed: () => _showAppSelector(isHabit: false),
                    child: const Text("+ ADD APP", style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ),
                  const SizedBox(height: 40),

                  _buildSectionHeader("FOCUS LIST"),
                  TextField(
                    controller: _taskController,
                    onSubmitted: _addTask,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                    decoration: const InputDecoration(
                      hintText: "add a task...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.tasks.isEmpty)
                    const Text("No tasks for today.", style: TextStyle(color: Colors.white38))
                  else
                    ...widget.tasks.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> task = entry.value;
                      return DashboardItem(
                        title: task['title'] ?? 'No Title',
                        description: task['description'] ?? '',
                        isAction: true,
                        onDelete: () => _deleteTask(index),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("DASHBOARD", style: TextStyle(letterSpacing: 4, color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(DateFormat('MMMM d').format(DateTime.now()).toUpperCase(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
    );
  }
}

// --- DashboardItem Widget ---
class DashboardItem extends StatefulWidget {
  final String title;
  final String description;
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
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                    if (_isExpanded && widget.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(widget.description, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w300)),
                      ),
                    if (!_isExpanded && widget.description.isNotEmpty && widget.isAction)
                      const Text("tap to see description...", style: TextStyle(color: Colors.white10, fontSize: 10)),
                    if (!widget.isAction)
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