import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class PredictedLabel {
  final String label;
  final double score;

  const PredictedLabel({required this.label, required this.score});
}

/// ML Kit 영문 레이블 → 한국어 번역 맵
const Map<String, String> _kLabelMap = {
  // 음식 일반
  'Food': '음식', 'Dish': '요리', 'Meal': '식사', 'Snack': '간식',
  'Cuisine': '요리', 'Ingredient': '식재료', 'Recipe': '레시피',
  'Fast food': '패스트푸드', 'Junk food': '인스턴트 식품',

  // 과일
  'Fruit': '과일', 'Apple': '사과', 'Banana': '바나나', 'Orange': '오렌지',
  'Lemon': '레몬', 'Lime': '라임', 'Grape': '포도', 'Strawberry': '딸기',
  'Watermelon': '수박', 'Melon': '멜론', 'Peach': '복숭아', 'Pear': '배',
  'Mango': '망고', 'Pineapple': '파인애플', 'Kiwi': '키위', 'Cherry': '체리',
  'Blueberry': '블루베리', 'Raspberry': '라즈베리', 'Fig': '무화과',

  // 채소
  'Vegetable': '채소', 'Carrot': '당근', 'Potato': '감자',
  'Sweet potato': '고구마', 'Onion': '양파', 'Garlic': '마늘',
  'Tomato': '토마토', 'Lettuce': '상추', 'Cabbage': '양배추',
  'Broccoli': '브로콜리', 'Spinach': '시금치', 'Cucumber': '오이',
  'Pepper': '고추', 'Mushroom': '버섯', 'Corn': '옥수수',
  'Pumpkin': '호박', 'Eggplant': '가지', 'Radish': '무',

  // 곡물/빵
  'Bread': '빵', 'Rice': '쌀/밥', 'Noodle': '면', 'Pasta': '파스타',
  'Cake': '케이크', 'Cookie': '쿠키', 'Biscuit': '비스킷',
  'Cereal': '시리얼', 'Flour': '밀가루', 'Bagel': '베이글',
  'Muffin': '머핀', 'Waffle': '와플', 'Pancake': '팬케이크',
  'Croissant': '크루아상', 'Toast': '토스트', 'Sandwich': '샌드위치',
  'Hamburger': '햄버거', 'Hot dog': '핫도그', 'Pizza': '피자',
  'Sushi': '스시', 'Dumpling': '만두',

  // 유제품/달걀
  'Dairy': '유제품', 'Milk': '우유', 'Cheese': '치즈', 'Butter': '버터',
  'Yogurt': '요거트', 'Ice cream': '아이스크림', 'Egg': '달걀',

  // 육류/해산물
  'Meat': '고기', 'Chicken': '닭고기', 'Beef': '소고기',
  'Pork': '돼지고기', 'Fish': '생선/물고기', 'Seafood': '해산물',
  'Shrimp': '새우', 'Crab': '게', 'Lobster': '랍스터',
  'Salmon': '연어', 'Tuna': '참치', 'Sausage': '소시지',
  'Ham': '햄', 'Bacon': '베이컨',

  // 음료
  'Drink': '음료', 'Beverage': '음료', 'Water': '물',
  'Coffee': '커피', 'Tea': '차', 'Juice': '주스',
  'Soda': '탄산음료', 'Soft drink': '탄산음료', 'Carbonated water': '탄산수',
  'Cola': '콜라', 'Energy drink': '에너지 음료',
  'Beer': '맥주', 'Wine': '와인', 'Liquor': '주류', 'Alcohol': '술',
  'Cocktail': '칵테일', 'Smoothie': '스무디', 'Latte': '라떼',
  'Milk tea': '밀크티', 'Bubble tea': '버블티', 'Espresso': '에스프레소',
  'Americano': '아메리카노', 'Cappuccino': '카푸치노',

  // 가전/전자
  'Electronics': '전자기기', 'Phone': '휴대폰',
  'Mobile phone': '휴대폰', 'Smartphone': '스마트폰',
  'Computer': '컴퓨터', 'Laptop': '노트북', 'Tablet': '태블릿',
  'Camera': '카메라', 'Television': '텔레비전', 'Monitor': '모니터',
  'Keyboard': '키보드', 'Mouse': '마우스', 'Headphones': '헤드폰',
  'Earbuds': '이어폰', 'Speaker': '스피커', 'Charger': '충전기',
  'Battery': '배터리', 'Remote control': '리모컨',

  // 의류/패션
  'Clothing': '의류', 'Shirt': '셔츠', 'T-shirt': '티셔츠',
  'Pants': '바지', 'Jeans': '청바지', 'Shorts': '반바지',
  'Dress': '원피스', 'Skirt': '치마', 'Jacket': '재킷',
  'Coat': '코트', 'Sweater': '스웨터', 'Hoodie': '후드티',
  'Shoes': '신발', 'Sneakers': '운동화', 'Boots': '부츠',
  'Sandals': '샌들', 'Hat': '모자', 'Cap': '캡모자',
  'Gloves': '장갑', 'Scarf': '스카프', 'Socks': '양말',
  'Bag': '가방', 'Backpack': '백팩', 'Handbag': '핸드백',
  'Wallet': '지갑', 'Belt': '벨트', 'Sunglasses': '선글라스',
  'Watch': '시계', 'Ring': '반지', 'Necklace': '목걸이',
  'Earrings': '귀걸이', 'Bracelet': '팔찌',

  // 가구/인테리어
  'Furniture': '가구', 'Chair': '의자', 'Table': '테이블',
  'Desk': '책상', 'Sofa': '소파', 'Couch': '소파', 'Bed': '침대',
  'Bookcase': '책장', 'Shelf': '선반', 'Cabinet': '캐비닛',
  'Drawer': '서랍', 'Lamp': '램프', 'Mirror': '거울',
  'Curtain': '커튼', 'Pillow': '베개', 'Blanket': '담요',
  'Carpet': '카펫', 'Rug': '러그',

  // 주방용품
  'Kitchenware': '주방용품', 'Pot': '냄비', 'Pan': '팬',
  'Bowl': '그릇', 'Plate': '접시', 'Cup': '컵', 'Glass': '유리컵',
  'Mug': '머그컵', 'Bottle': '병', 'Spoon': '숟가락',
  'Fork': '포크', 'Knife': '칼/나이프', 'Chopsticks': '젓가락',
  'Cutting board': '도마', 'Refrigerator': '냉장고',
  'Microwave': '전자레인지', 'Oven': '오븐', 'Blender': '블렌더',

  // 문구/공부
  'Stationery': '문구류', 'Book': '책', 'Notebook': '노트',
  'Pen': '펜', 'Pencil': '연필', 'Eraser': '지우개',
  'Ruler': '자', 'Scissors': '가위', 'Tape': '테이프',
  'Paper': '종이', 'Envelope': '봉투',

  // 세면/뷰티
  'Cosmetics': '화장품', 'Shampoo': '샴푸', 'Soap': '비누',
  'Toothbrush': '칫솔', 'Toothpaste': '치약', 'Perfume': '향수',
  'Lipstick': '립스틱', 'Skincare': '스킨케어', 'Sunscreen': '선크림',
  'Cotton swab': '면봉', 'Cotton bud': '면봉', 'Swab': '면봉',
  'Cotton': '솜/면', 'Cotton ball': '솜뭉치',
  'Razor': '면도기', 'Comb': '빗', 'Hair brush': '헤어브러시',
  'Nail clipper': '손톱깎이', 'Tweezers': '핀셋', 'Lotion': '로션',
  'Toner': '토너', 'Serum': '세럼', 'Foundation': '파운데이션',
  'Mascara': '마스카라', 'Eyeshadow': '아이섀도', 'Blush': '블러셔',

  // 동물
  'Animal': '동물', 'Dog': '강아지', 'Cat': '고양이', 'Bird': '새',
  'Rabbit': '토끼', 'Hamster': '햄스터',

  // 식물/화분
  'Plant': '식물', 'Flower': '꽃', 'Tree': '나무', 'Grass': '잔디',
  'Cactus': '선인장', 'Rose': '장미', 'Tulip': '튤립',

  // 운송
  'Vehicle': '탈것', 'Car': '자동차', 'Bus': '버스',
  'Bicycle': '자전거', 'Motorcycle': '오토바이', 'Truck': '트럭',

  // 스포츠/건강
  'Sports': '스포츠', 'Exercise': '운동', 'Ball': '공',
  'Dumbbell': '덤벨', 'Yoga mat': '요가매트',

  // 의약품/건강용품
  'Medicine': '약', 'Vitamin': '비타민', 'Capsule': '캡슐',
  'Pill': '알약', 'Bandage': '붕대', 'Mask': '마스크',

  // 청소용품
  'Cleaning': '청소용품', 'Detergent': '세제', 'Sponge': '스펀지',
  'Broom': '빗자루', 'Vacuum': '청소기',

  // 용기/포장
  'Can': '캔', 'Tin': '캔', 'Jar': '유리병', 'Carton': '종이팩',
  'Plastic bottle': '플라스틱 병', 'Aluminum can': '알루미늄 캔',

  // 기타 일반
  'Box': '상자', 'Container': '용기', 'Key': '열쇠',
  'Toy': '장난감', 'Gift': '선물', 'Candle': '양초',
  'Umbrella': '우산', 'Flashlight': '손전등',
};

/// 영문 레이블을 한국어로 변환. 대소문자 구분 없이 검색하며, 매핑이 없으면 원래 영문 반환.
String _toKorean(String label) {
  // 1차: 정확히 일치
  if (_kLabelMap.containsKey(label)) return _kLabelMap[label]!;
  // 2차: 대소문자 무시 매칭
  final lower = label.toLowerCase();
  for (final entry in _kLabelMap.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return label;
}

/// 사진을 찍거나 갤러리에서 선택하면 ML Kit으로 객체를 인식하고,
/// 인식된 라벨 중 하나를 탭하면 [onLabelSelected]로 반환합니다.
class PhotoLabelPicker extends StatefulWidget {
  final Function(String label) onLabelSelected;

  const PhotoLabelPicker({super.key, required this.onLabelSelected});

  @override
  State<PhotoLabelPicker> createState() => _PhotoLabelPickerState();
}

class _PhotoLabelPickerState extends State<PhotoLabelPicker> {
  static String get _apiBaseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:5000'
      : 'http://localhost:5000';

  bool _isProcessing = false;
  File? _imageFile;
  List<PredictedLabel> _labels = [];
  List<String> _ocrTexts = []; // OCR로 인식된 단어 목록
  String? _errorMessage;

  Future<Map<String, dynamic>> _analyzeWithFlask(File imageFile) async {
    final uri = Uri.parse('$_apiBaseUrl/analyze');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('API ${streamedResponse.statusCode}: $responseBody');
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('잘못된 API 응답 형식');
    }

    return decoded;
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.gallery) {
      return true;
    }

    final permission = Permission.camera;

    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    status = await permission.request();
    if (status.isGranted || status.isLimited) return true;

    if (!mounted) return false;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 필요'),
        content: const Text('카메라 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );

    return false;
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final hasPermission = await _ensurePermission(source);
    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _errorMessage = '권한이 없어 사진을 불러올 수 없어요.';
      });
      return;
    }

    setState(() {
      _isProcessing = false;
      _imageFile = null;
      _labels = [];
      _ocrTexts = [];
      _errorMessage = null;
    });

    // macOS는 카메라 미지원 → gallery로 대체
    final effectiveSource =
        (defaultTargetPlatform == TargetPlatform.macOS &&
                source == ImageSource.camera)
            ? ImageSource.gallery
            : source;

    final picker = ImagePicker();
    XFile? xFile;
    try {
      xFile = await picker.pickImage(
        source: effectiveSource,
        imageQuality: 85,
        maxWidth: 1024,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '사진을 불러오는 중 오류가 발생했어요: $e';
      });
      return;
    }
    if (!mounted) return;

    if (xFile == null) {
      setState(() {
        _errorMessage = '사진 선택이 취소되었어요.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _imageFile = File(xFile!.path);
    });

    final selectedFile = File(xFile.path);

    try {
      final apiResult = await _analyzeWithFlask(selectedFile);

      if (!mounted) return;

      final labelsJson = (apiResult['labels'] as List<dynamic>? ?? []);
      final ocrJson = (apiResult['ocr_texts'] as List<dynamic>? ?? []);

      final parsedLabels = labelsJson
          .whereType<Map>()
          .map(
            (e) => PredictedLabel(
              label: (e['label'] as String? ?? '').trim(),
              score: (e['score'] as num? ?? 0).toDouble(),
            ),
          )
          .where((e) => e.label.isNotEmpty)
          .toList();

      final parsedOcr = ocrJson
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.length >= 2)
          .toList();

      setState(() {
        _labels = parsedLabels.take(5).toList();
        _ocrTexts = parsedOcr.take(8).toList();
        _isProcessing = false;
        if (_labels.isEmpty && _ocrTexts.isEmpty) {
          _errorMessage = '인식된 항목이 없어요. 다시 시도해보세요.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = '서버 인식 중 오류가 발생했어요. Flask 서버 실행 상태를 확인해주세요.';
      });
    }
  }

  Future<void> _showSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
              if (defaultTargetPlatform == TargetPlatform.macOS)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '※ macOS에서는 카메라 대신 파일 선택창이 열립니다',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade400),
                  ),
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
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.photo_library_rounded,
                      label: '갤러리',
                      color: const Color(0xFF26C6DA),
                      bgColor: const Color(0xFFE0F7FA),
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.gallery),
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

    if (source == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _pickAndAnalyze(source);
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
                      : (_labels.isNotEmpty || _ocrTexts.isNotEmpty)
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
    final isKorean =
        Localizations.localeOf(context).languageCode == 'ko';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OCR 텍스트 섹션 (포장지 글자)
        if (_ocrTexts.isNotEmpty) ...[
          Text(
            '📝 인식된 텍스트',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _ocrTexts.map((text) {
              return GestureDetector(
                onTap: () => widget.onLabelSelected(text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26C6DA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // 이미지 라벨링 섹션
        if (_labels.isNotEmpty) ...[
          if (_ocrTexts.isNotEmpty) const SizedBox(height: 10),
          Text(
            '🏷️ 인식된 항목',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _labels.map((label) {
              final confidence = (label.score * 100).toInt();
              final displayText = isKorean ? _toKorean(label.label) : label.label;
              return GestureDetector(
                onTap: () => widget.onLabelSelected(displayText),
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
                        displayText,
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
