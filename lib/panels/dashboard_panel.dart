import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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

// --- Sub-Widget: DashboardItem ---
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