import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:installed_apps/app_info.dart';

class DashboardPanel extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final Duration screenTime;
  final Function(List<Map<String, dynamic>>) onTasksChanged;
  final List<String> watchedPackages;
  final List<AppInfo> allApps;
  final Function(String) onToggleWatch;
  final List<String> quickApps;
  final Function(String) onToggleQuickApp;
  final bool isInitialLoading;

  const DashboardPanel({
    super.key,
    required this.tasks,
    required this.screenTime,
    required this.onTasksChanged,
    required this.watchedPackages,
    required this.allApps,
    required this.onToggleWatch,
    required this.quickApps,
    required this.onToggleQuickApp,
    required this.isInitialLoading,
  });

  @override
  State<DashboardPanel> createState() => _DashboardPanelState();
}

class _DashboardPanelState extends State<DashboardPanel> with AutomaticKeepAliveClientMixin {
  late Map<String, AppInfo> _appLookupMap;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _generateAppMap();
  }

  @override
  void didUpdateWidget(DashboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allApps != oldWidget.allApps) {
      _generateAppMap();
    }
  }

  void _generateAppMap() {
    _appLookupMap = {for (var app in widget.allApps) app.packageName: app};
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DASHBOARD SETTINGS", style: TextStyle(letterSpacing: 2, color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  _buildSettingsSection(
                    title: "DAILY HABITS",
                    packages: widget.watchedPackages,
                    onAdd: () => _showAppSelector(isHabit: true, onUpdate: () => setModalState(() {})),
                    onRemove: (pkg) {
                      widget.onToggleWatch(pkg);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 40),
                  _buildSettingsSection(
                    title: "QUICK ACCESS",
                    packages: widget.quickApps,
                    onAdd: () => _showAppSelector(isHabit: false, onUpdate: () => setModalState(() {})),
                    onRemove: (pkg) {
                      widget.onToggleQuickApp(pkg);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<String> packages, required VoidCallback onAdd, required Function(String) onRemove}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Colors.white24, size: 20)),
          ],
        ),
        if (packages.isEmpty)
          const Text("None selected", style: TextStyle(color: Colors.white10, fontSize: 12))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packages.map((pkg) {
              final app = _appLookupMap[pkg];
              return Container(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(app?.name.toLowerCase() ?? "unknown", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.white24),
                      onPressed: () => onRemove(pkg),
                    )
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAppSelector({required bool isHabit, required VoidCallback onUpdate}) {
    List<AppInfo> filteredApps = List.from(widget.allApps);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setModalState(() => filteredApps = widget.allApps.where((a) => a.name.toLowerCase().contains(v.toLowerCase())).toList()),
                  decoration: const InputDecoration(hintText: "Search apps...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white24)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredApps.length,
                  itemExtent: 50,
                  itemBuilder: (context, i) {
                    final app = filteredApps[i];
                    return ListTile(
                      title: Text(app.name.toLowerCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        isHabit ? widget.onToggleWatch(app.packageName) : widget.onToggleQuickApp(app.packageName);
                        onUpdate();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(left: 40.0, right: 20.0, top: 80.0),
            sliver: SliverToBoxAdapter(child: _DashboardHeader(onSettingsPressed: _showSettingsPanel)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("FOCUS LIST", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                  TaskInputSection(onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      widget.onTasksChanged(List<Map<String, dynamic>>.from(widget.tasks)..add({'title': val.trim(), 'description': ''}));
                    }
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final task = widget.tasks[index];
                  return DashboardItem(
                    key: ValueKey(task['title']),
                    title: task['title'] ?? '',
                    description: task['description'] ?? '',
                    isAction: true,
                    onDelete: () {
                      widget.onTasksChanged(List<Map<String, dynamic>>.from(widget.tasks)..removeAt(index));
                      HapticFeedback.mediumImpact();
                    },
                    onEdit: (t, d) {
                      final newTasks = List<Map<String, dynamic>>.from(widget.tasks);
                      newTasks[index] = {'title': t, 'description': d};
                      widget.onTasksChanged(newTasks);
                    },
                  );
                },
                childCount: widget.tasks.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onSettingsPressed;
  const _DashboardHeader({required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("DASHBOARD", style: TextStyle(letterSpacing: 4, color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(DateFormat('MMMM d').format(DateTime.now()).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
          ],
        ),
        IconButton(onPressed: onSettingsPressed, icon: const Icon(Icons.tune, color: Colors.white30, size: 24)),
      ],
    );
  }
}

class TaskInputSection extends StatefulWidget {
  final Function(String) onSubmitted;
  const TaskInputSection({super.key, required this.onSubmitted});

  @override
  State<TaskInputSection> createState() => _TaskInputSectionState();
}

class _TaskInputSectionState extends State<TaskInputSection> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (v) {
          widget.onSubmitted(v);
          _controller.clear();
          _focusNode.requestFocus();
        },
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
        decoration: const InputDecoration(hintText: "add a task...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
      ),
    );
  }
}

class DashboardItem extends StatefulWidget {
  final String title;
  final String description;
  final bool isAction;
  final VoidCallback onDelete;
  final Function(String, String) onEdit;

  const DashboardItem({super.key, required this.title, required this.description, required this.isAction, required this.onDelete, required this.onEdit});

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
      // Gunakan 'useSafeArea' agar lebih aman di HP berponi
      useSafeArea: true, 
      builder: (context) {
        // Kita gunakan Padding dinamis di sini, tapi konten di dalamnya dibungkus 
        // agar tidak melakukan kalkulasi layout yang berat.
        return Padding(
          // MediaQuery diletakkan di sini untuk menangkap perubahan tinggi keyboard
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(30),
            // SingleChildScrollView mencegah error 'pixel overflow' saat keyboard muncul
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("EDIT TASK", 
                    style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)
                  ),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(hintText: "Title", border: InputBorder.none),
                    autofocus: true,
                    // Optimasi: Matikan autocorrect jika tidak perlu untuk kurangi beban
                    autocorrect: false, 
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
                  ),
                  // Tambahkan sedikit ruang di paling bawah agar tidak nempel banget sama keyboard
                  const SizedBox(height: 20), 
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { if (widget.description.isNotEmpty) setState(() => _isExpanded = !_isExpanded); },
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
                    Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(widget.description, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w300))),
                  if (!_isExpanded && widget.description.isNotEmpty && widget.isAction)
                    const Text("tap to see description...", style: TextStyle(color: Colors.white10, fontSize: 10)),
                ],
              ),
            ),
            if (widget.isAction) IconButton(icon: const Icon(Icons.edit_note, color: Colors.white10, size: 20), onPressed: () => _showEditSheet(context)),
          ],
        ),
      ),
    );
  }
}