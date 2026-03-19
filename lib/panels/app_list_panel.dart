import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'dart:math';

class AppListPanel extends StatefulWidget {
  final bool isInitialLoading;
  final List<AppInfo> apps;
  const AppListPanel({
    super.key,
    required this.apps,
    required this.isInitialLoading,
  });

  @override
  State<AppListPanel> createState() => _AppListPanelState();
}

class _AppListPanelState extends State<AppListPanel> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<AppInfo> _filteredApps = [];
  final Map<String, int> _alphabetMap = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filteredApps = widget.apps;
    _buildAlphabetMap();
  }

  @override
  void didUpdateWidget(AppListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apps.length != oldWidget.apps.length) {
      _filteredApps = _searchController.text.isEmpty 
          ? widget.apps 
          : widget.apps.where((app) => app.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      _buildAlphabetMap();
      setState(() {});
    }
  }

  void _buildAlphabetMap() {
    _alphabetMap.clear();
    for (int i = 0; i < _filteredApps.length; i++) {
      String char = _filteredApps[i].name[0].toUpperCase();
      if (!RegExp(r'[A-Z]').hasMatch(char)) char = '#';
      if (!_alphabetMap.containsKey(char)) {
        _alphabetMap[char] = i;
      }
    }
  }

  void _filterApps(String query) {
    setState(() {
      _filteredApps = widget.apps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _buildAlphabetMap(); // PENTING: Update map setelah filter
    });
  }

  void _scrollToLetter(String letter) {
    final index = _alphabetMap[letter];
    if (index != null && _scrollController.hasClients) {
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
              padding: const EdgeInsets.only(left: 40.0, top: 80.0, bottom: 40.0, right: 60.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("APPS", style: TextStyle(letterSpacing: 4, color: Colors.white54, fontSize: 10)),
                  TextField(
                    controller: _searchController,
                    onChanged: _filterApps,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      hintText: "search", 
                      hintStyle: TextStyle(color: Colors.white24), 
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: Colors.white24),
                            onPressed: () {
                              _searchController.clear();
                              _filterApps("");
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                      ),
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

class AlphabetSidebar extends StatefulWidget {
  final Function(String) onLetterSelected;
  const AlphabetSidebar({super.key, required this.onLetterSelected});

  @override
  State<AlphabetSidebar> createState() => _AlphabetSidebarState();
}

class _AlphabetSidebarState extends State<AlphabetSidebar> {
  final List<String> _alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  
  // Gunakan ValueNotifier agar tidak perlu memanggil setState di seluruh widget
  final ValueNotifier<Offset?> _touchPos = ValueNotifier(null);
  String _lastLetter = "";

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => _handleUpdate(details.localPosition),
      onVerticalDragStart: (details) => _handleUpdate(details.localPosition),
      onVerticalDragEnd: (_) => _touchPos.value = null,
      onTapDown: (details) => _handleUpdate(details.localPosition),
      onTapUp: (_) => _touchPos.value = null,
      child: ValueListenableBuilder<Offset?>(
        valueListenable: _touchPos,
        builder: (context, pos, _) {
          return CustomPaint(
            size: Size(60, double.infinity),
            painter: SidebarPainter(
              alphabet: _alphabet,
              touchPos: pos,
            ),
          );
        },
      ),
    );
  }

  void _handleUpdate(Offset localPos) {
    _touchPos.value = localPos;
    
    // Logika perhitungan huruf tetap di luar Painter untuk urusan data
    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    double itemHeight = box.size.height / _alphabet.length;
    int index = (localPos.dy / itemHeight).floor().clamp(0, _alphabet.length - 1);
    String currentLetter = _alphabet[index];

    if (currentLetter != _lastLetter) {
      _lastLetter = currentLetter;
      widget.onLetterSelected(currentLetter);
      HapticFeedback.selectionClick();
    }
  }
}

// PAINTER: Ini rahasia performa tinggi
class SidebarPainter extends CustomPainter {
  final List<String> alphabet;
  final Offset? touchPos;

  SidebarPainter({required this.alphabet, required this.touchPos});

  @override
  void paint(Canvas canvas, Size size) {
    double itemHeight = size.height / alphabet.length;
    
    for (int i = 0; i < alphabet.length; i++) {
      double letterY = i * itemHeight + (itemHeight / 2);
      double factor = 0.0;

      if (touchPos != null) {
        double dist = (touchPos!.dy - letterY).abs();
        if (dist < 120) {
          factor = pow(1.0 - (dist / 120).clamp(0.0, 1.0), 3).toDouble();
        }
      }

      // Gambar Teks secara primitif
      final textPainter = TextPainter(
        text: TextSpan(
          text: alphabet[i],
          style: TextStyle(
            color: factor > 0.2 ? Colors.white : Colors.white24,
            fontSize: 10 + (20 * factor),
            fontWeight: factor > 0.2 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Hitung posisi x (efek melengkung)
      double xPos = size.width - 20 - (60 * factor);
      textPainter.paint(canvas, Offset(xPos - textPainter.width / 2, letterY - textPainter.height / 2));
      
      // Gambar Bubble besar jika sedang disentuh
      if (factor > 0.8 && touchPos != null) {
         _drawBubble(canvas, alphabet[i], touchPos!.dy);
      }
    }
  }

  void _drawBubble(Canvas canvas, String letter, double y) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-60, y), 35, paint);
    
    final tp = TextPainter(
      text: TextSpan(text: letter, style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-60 - tp.width/2, y - tp.height/2));
  }

  @override
  bool shouldRepaint(SidebarPainter oldDelegate) => touchPos != oldDelegate.touchPos;
}

// AppListItem tetap sama
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