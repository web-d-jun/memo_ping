import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/memo_item.dart';
import '../widgets/photo_label_picker.dart';
import 'location_picker_screen.dart';

class AddMemoScreen extends StatefulWidget {
  final MemoItem? initialMemo;

  const AddMemoScreen({super.key, this.initialMemo});

  @override
  State<AddMemoScreen> createState() => _AddMemoScreenState();
}

class _AddMemoScreenState extends State<AddMemoScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;

  late TriggerType _triggerType;
  late double _radius;
  late TimeOfDay _selectedTime;
  late List<bool> _repeatDays;
  LatLng? _pickedLatLng; // 지도에서 선택한 좌표
  bool get _isEditing => widget.initialMemo != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMemo;
    _titleController = TextEditingController(text: m?.title ?? '');
    _descController = TextEditingController(text: m?.description ?? '');
    _locationController = TextEditingController(text: m?.locationName ?? '');
    _triggerType = m?.triggerType ?? TriggerType.location;
    _radius = m?.radius ?? 200;
    _selectedTime = m?.triggerTime ?? const TimeOfDay(hour: 9, minute: 0);
    _repeatDays = m != null ? List.from(m.repeatDays) : List.filled(7, false);
    // 수정 모드: 기존 좌표 복원
    if (m?.latitude != null && m?.longitude != null) {
      _pickedLatLng = LatLng(m!.latitude!, m.longitude!);
    }
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      (_triggerType == TriggerType.location
          ? _locationController.text.trim().isNotEmpty && _pickedLatLng != null
          : true);

  void _save() {
    if (!_canSave) return;
    final memo = MemoItem(
      id: widget.initialMemo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      triggerType: _triggerType,
      locationName: _locationController.text.trim(),
      radius: _radius,
      latitude: _pickedLatLng?.latitude,
      longitude: _pickedLatLng?.longitude,
      triggerTime:
          _triggerType == TriggerType.time ? _selectedTime : null,
      repeatDays: List.from(_repeatDays),
      isActive: widget.initialMemo?.isActive ?? true,
    );
    Navigator.pop(context, memo);
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialPosition: _pickedLatLng,
          initialRadius: _radius,
        ),
      ),
    );
    if (result != null) {
      setState(() => _pickedLatLng = result);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: const Color(0xFF1A1A2E),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? '메모 수정' : '새 메모 추가',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메모 내용 섹션
            _buildSection(
              title: '메모 내용',
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    hint: '무엇을 기억해야 하나요?',
                    icon: Icons.edit_rounded,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // AI 사진 인식
                  PhotoLabelPicker(
                    onLabelSelected: (label) {
                      setState(() {
                        _titleController.text = label;
                        _titleController.selection = TextSelection.fromPosition(
                          TextPosition(offset: label.length),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descController,
                    hint: '상세 내용 (선택)',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 알림 방식 섹션
            _buildSection(
              title: '알림 방식',
              child: Row(
                children: [
                  _triggerOption(
                    TriggerType.location,
                    '위치 알림',
                    Icons.location_on_rounded,
                    const Color(0xFF26C6DA),
                    const Color(0xFFE0F7FA),
                  ),
                  const SizedBox(width: 12),
                  _triggerOption(
                    TriggerType.time,
                    '시간 알림',
                    Icons.access_time_rounded,
                    const Color(0xFFFF8A65),
                    const Color(0xFFFBE9E7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 위치/시간 설정 섹션 (애니메이션 전환)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _triggerType == TriggerType.location
                  ? _buildSection(
                      key: const ValueKey('location'),
                      title: '위치 설정',
                      child: _buildLocationFields(),
                    )
                  : _buildSection(
                      key: const ValueKey('time'),
                      title: '시간 설정',
                      child: _buildTimeFields(),
                    ),
            ),
            const SizedBox(height: 28),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isEditing ? '수정 완료' : '저장하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _canSave ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5C6BC0),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F6FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _triggerOption(
    TriggerType type,
    String label,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    final selected = _triggerType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _triggerType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? color : bgColor,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: color, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : color, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationFields() {
    const radiusOptions = [50.0, 100.0, 200.0, 500.0, 1000.0];
    const radiusLabels = ['50m', '100m', '200m', '500m', '1km'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _locationController,
          hint: '장소 이름 (예: 김밥천국, 다이소, GS25)',
          icon: Icons.store_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        // 지도에서 위치 선택 버튼
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: _pickedLatLng != null
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF5F6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pickedLatLng != null
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF26C6DA),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _pickedLatLng != null
                      ? Icons.check_circle_rounded
                      : Icons.map_rounded,
                  color: _pickedLatLng != null
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF26C6DA),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pickedLatLng != null
                      ? Text(
                          '${_pickedLatLng!.latitude.toStringAsFixed(5)}, '
                          '${_pickedLatLng!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF66BB6A),
                          ),
                        )
                      : const Text(
                          '지도에서 위치 선택',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF26C6DA),
                          ),
                        ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _pickedLatLng != null
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF26C6DA),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '알림 반경',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _radius >= 1000
                    ? '${(_radius / 1000).toStringAsFixed(0)}km'
                    : '${_radius.toInt()}m',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF26C6DA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF26C6DA),
            inactiveTrackColor: const Color(0xFFE0F7FA),
            thumbColor: const Color(0xFF26C6DA),
            overlayColor: Color(0xFF26C6DA).withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: _radius,
            min: 50,
            max: 1000,
            divisions: 4,
            onChanged: (v) {
              final snapped = radiusOptions.reduce(
                (a, b) => (a - v).abs() < (b - v).abs() ? a : b,
              );
              setState(() => _radius = snapped);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: radiusLabels.map((l) {
            final isSelected = radiusLabels[radiusOptions.indexOf(
                    radiusOptions.firstWhere((r) => r == _radius))] ==
                l;
            return Text(
              l,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF26C6DA)
                    : Colors.grey.shade400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeFields() {
    final h = _selectedTime.hour;
    final m = _selectedTime.minute;
    final period = h < 12 ? '오전' : '오후';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayMin = m.toString().padLeft(2, '0');
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시간 선택 버튼
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE9E7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$period $displayHour:$displayMin',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF8A65),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '탭하여 시간 변경',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '반복 요일',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        // 요일 선택
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final selected = _repeatDays[i];
            return GestureDetector(
              onTap: () => setState(() => _repeatDays[i] = !_repeatDays[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFF8A65)
                      : const Color(0xFFFBE9E7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  dayLabels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFFFF8A65),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // 빠른 선택 버튼들
        Row(
          children: [
            _quickDayButton('매일', List.filled(7, true)),
            const SizedBox(width: 8),
            _quickDayButton('평일', [true, true, true, true, true, false, false]),
            const SizedBox(width: 8),
            _quickDayButton('주말', [false, false, false, false, false, true, true]),
          ],
        ),
      ],
    );
  }

  Widget _quickDayButton(String label, List<bool> days) {
    return GestureDetector(
      onTap: () => setState(() {
        for (int i = 0; i < 7; i++) {
          _repeatDays[i] = days[i];
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFBE9E7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF8A65),
          ),
        ),
      ),
    );
  }
}
