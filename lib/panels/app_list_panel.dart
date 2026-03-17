import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'dart:math';

class AppListPanel extends StatefulWidget {
  final bool isInitialLoading; // Tambahkan ini
  final List<AppInfo> apps;
  const AppListPanel({
    super.key,
    required this.apps,
    required this.isInitialLoading
    });
  

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
    _filteredApps = widget.apps;
  }

  @override
  void didUpdateWidget(AppListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apps.length != oldWidget.apps.length) {
      setState(() {
        if (_searchController.text.isEmpty) {
          _filteredApps = widget.apps;
        } else {
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
    int index = _filteredApps.indexWhere((app) => app.name.toUpperCase().startsWith(letter));
    if (index != -1) _scrollController.jumpTo(index * 52.0);
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
              padding: const EdgeInsets.only(left: 40.0, top: 80.0, bottom: 40.0, right: 60.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("APPS", style: TextStyle(letterSpacing: 4, color: Colors.white54, fontSize: 10)),
                  TextField(
                    controller: _searchController,
                    onChanged: _filterApps,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400),
                    decoration: const InputDecoration(hintText: "search", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: widget.isInitialLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                      : _filteredApps.isEmpty 
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
          Positioned(
            right: 0, top: 120, bottom: 60, width: 80,
            child: AlphabetSidebar(onLetterSelected: _scrollToLetter),
          ),
        ],
      ),
    );
  }
}

// --- Sub-Widget: AlphabetSidebar & AppListItem ---
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
    setState(() => _touchY = localPos.dy);
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
        onVerticalDragEnd: (_) => setState(() { _isDragging = false; _lastLetter = ""; }),
        child: Stack(
          alignment: Alignment.centerRight,
          clipBehavior: Clip.none,
          children: [
            ...List.generate(_alphabet.length, (i) {
              double factor = 0.0;
              if (_isDragging) {
                double letterY = i * itemHeight + (itemHeight / 2);
                double dist = (_touchY - letterY).abs();
                if (dist < 150) factor = pow(1 - (dist / 150), 3).toDouble();
              }
              return Positioned(
                top: i * itemHeight,
                right: 15 + (80 * factor),
                child: IgnorePointer(
                  child: Text(_alphabet[i],
                    style: TextStyle(
                      fontSize: 10 + (25 * factor),
                      color: factor > 0.2 ? Colors.white : Colors.white24,
                      fontWeight: factor > 0.2 ? FontWeight.w900 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
            if (_isDragging && _lastLetter.isNotEmpty)
              Positioned(
                top: _touchY - 60, right: 100,
                child: Container(
                  width: 70, height: 70, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                  child: Text(_lastLetter, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
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
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(width: 2, height: 20, color: Colors.white10),
            const SizedBox(width: 16),
            Expanded(
              child: Text(app.name.toLowerCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}