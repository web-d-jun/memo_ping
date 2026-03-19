import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

/// 사진을 찍거나 갤러리에서 선택하면 ML Kit으로 객체를 인식하고,
/// 인식된 라벨 중 하나를 탭하면 [onLabelSelected]로 반환합니다.
class PhotoLabelPicker extends StatefulWidget {
  final Function(String label) onLabelSelected;

  const PhotoLabelPicker({super.key, required this.onLabelSelected});

  @override
  State<PhotoLabelPicker> createState() => _PhotoLabelPickerState();
}

class _PhotoLabelPickerState extends State<PhotoLabelPicker> {
  bool _isProcessing = false;
  File? _imageFile;
  List<ImageLabel> _labels = [];
  String? _errorMessage;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    setState(() {
      _isProcessing = false;
      _imageFile = null;
      _labels = [];
      _errorMessage = null;
    });

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xFile == null) return;

    setState(() {
      _isProcessing = true;
      _imageFile = File(xFile.path);
    });

    final inputImage = InputImage.fromFilePath(xFile.path);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.55),
    );

    try {
      final labels = await labeler.processImage(inputImage);
      setState(() {
        _labels = labels.take(5).toList();
        _isProcessing = false;
        if (_labels.isEmpty) {
          _errorMessage = '인식된 항목이 없어요. 다시 시도해보세요.';
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '인식 중 오류가 발생했어요.';
      });
    } finally {
      await labeler.close();
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '사진으로 메모 인식',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '사진을 찍으면 포함된 물건이 자동으로 입력됩니다',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: '카메라',
                      color: const Color(0xFF5C6BC0),
                      bgColor: const Color(0xFFEDE7F6),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndAnalyze(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.photo_library_rounded,
                      label: '갤러리',
                      color: const Color(0xFF26C6DA),
                      bgColor: const Color(0xFFE0F7FA),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndAnalyze(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카메라 버튼
        GestureDetector(
          onTap: _showSourcePicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF5C6BC0).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF5C6BC0),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '사진 찍어서 자동 입력',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C6BC0),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 처리 중 / 결과 영역
        if (_isProcessing || _imageFile != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.grey.shade200, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 썸네일
                if (_imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _imageFile!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                // 라벨 영역
                Expanded(
                  child: _isProcessing
                      ? _buildProcessing()
                      : _labels.isNotEmpty
                          ? _buildLabels()
                          : _buildError(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProcessing() {
    return SizedBox(
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF5C6BC0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI가 사진을 분석 중...',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '인식된 항목 (탭하여 입력)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _labels.map((label) {
            final confidence = (label.confidence * 100).toInt();
            return GestureDetector(
              onTap: () => widget.onLabelSelected(label.label),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$confidence%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 72,
      child: Center(
        child: Text(
          _errorMessage ?? '인식에 실패했어요.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}
