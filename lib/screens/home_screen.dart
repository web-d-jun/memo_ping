import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/memo_item.dart';
import '../widgets/memo_card.dart';
import 'add_memo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilter = 0; // 0: 전체, 1: 위치, 2: 시간

  final List<MemoItem> _memos = [
    MemoItem(
      id: '1',
      title: '김밥',
      description: '김밥천국에서 포장해오기',
      triggerType: TriggerType.location,
      locationName: '김밥천국',
      radius: 200,
      isActive: true,
    ),
    MemoItem(
      id: '2',
      title: '머리핀',
      description: '작은 걸로 2개, 큰 걸로 1개',
      triggerType: TriggerType.location,
      locationName: '다이소',
      radius: 100,
      isActive: true,
    ),
    MemoItem(
      id: '3',
      title: '약 먹기',
      description: '비타민 + 유산균',
      triggerType: TriggerType.time,
      triggerTime: const TimeOfDay(hour: 9, minute: 0),
      repeatDays: [true, true, true, true, true, true, true],
      isActive: true,
    ),
    MemoItem(
      id: '4',
      title: '우유',
      triggerType: TriggerType.location,
      locationName: 'GS25 편의점',
      radius: 100,
      isActive: false,
    ),
  ];

  List<MemoItem> get _filteredMemos {
    if (_selectedFilter == 1) {
      return _memos
          .where((m) => m.triggerType == TriggerType.location)
          .toList();
    }
    if (_selectedFilter == 2) {
      return _memos.where((m) => m.triggerType == TriggerType.time).toList();
    }
    return _memos;
  }

  int get _activeCount => _memos.where((m) => m.isActive).length;
  int get _locationCount =>
      _memos.where((m) => m.triggerType == TriggerType.location).length;
  int get _timeCount =>
      _memos.where((m) => m.triggerType == TriggerType.time).length;

  void _toggleMemo(String id) {
    setState(() {
      final idx = _memos.indexWhere((m) => m.id == id);
      if (idx != -1) _memos[idx].isActive = !_memos[idx].isActive;
    });
  }

  void _deleteMemo(String id) {
    setState(() => _memos.removeWhere((m) => m.id == id));
  }

  Future<void> _preRequestCameraPermission() async {
    if (kIsWeb) return;

    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited || status.isPermanentlyDenied) {
      return;
    }

    await Permission.camera.request();
  }

  Future<void> _openAddMemo() async {
    await _preRequestCameraPermission();
    final result = await Navigator.push<MemoItem>(
      context,
      MaterialPageRoute(builder: (_) => const AddMemoScreen()),
    );
    if (result != null) {
      setState(() => _memos.insert(0, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMemos;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStats(),
            _buildFilterChips(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => MemoCard(
                        item: filtered[i],
                        onToggle: () => _toggleMemo(filtered[i].id),
                        onTap: () {},
                        onDelete: () => _deleteMemo(filtered[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemo,
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          '메모 추가',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '메모핑 🔔',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '잊지 말아야 할 것들을 알려드릴게요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: const Color(0xFF5C6BC0),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF5C6BC0).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('전체', _memos.length.toString(), Icons.list_rounded),
          _statDivider(),
          _statItem('활성', _activeCount.toString(),
              Icons.check_circle_outline_rounded),
          _statDivider(),
          _statItem(
              '위치', _locationCount.toString(), Icons.location_on_rounded),
          _statDivider(),
          _statItem(
              '시간', _timeCount.toString(), Icons.access_time_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style:
              TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('전체', Icons.apps_rounded),
      ('위치 알림', Icons.location_on_rounded),
      ('시간 알림', Icons.access_time_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _selectedFilter == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFF5C6BC0) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Color(0xFF5C6BC0).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filters[i].$2,
                      size: 14,
                      color: selected
                          ? Colors.white
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      filters[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '아직 메모가 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 메모 추가 버튼을 눌러 시작해보세요',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
