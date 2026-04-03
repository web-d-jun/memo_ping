from flask import Flask, jsonify, request
import re
from functools import lru_cache
from PIL import Image
from transformers import (
    CLIPProcessor, CLIPModel,
    BlipProcessor, BlipForConditionalGeneration,
    pipeline,
)
import torch

app = Flask(__name__)

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32

# CLIP — 후보 라벨과 이미지를 직접 비교 (zero-shot 분류)
clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
clip_model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32").to(device)
clip_model.eval()

# BLIP — CLIP 확신도가 낮을 때 캡셔닝 폴백
blip_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
blip_model = BlipForConditionalGeneration.from_pretrained(
    "Salesforce/blip-image-captioning-base", torch_dtype=dtype
).to(device)
blip_model.eval()

# CLIP 후보가 ~100개일 때 균등 확률 ≈ 0.01.
# 이 값 미만이면 "후보에 맞는 것 없음"으로 판단해 BLIP 폴백 사용.
CLIP_CONFIDENCE_THRESHOLD = 0.04

# ─────────────────────────────────────────────
# 후보 라벨 목록 — CLIP이 이미지와 직접 비교할 영문 라벨
# 여기에 있어야 인식 결과로 나올 수 있음
# ─────────────────────────────────────────────
CANDIDATE_LABELS: list[str] = [
    # 헤어 액세서리
    "hair tie", "hair band", "hair elastic", "scrunchie", "elastic band",
    "hair clip", "hair pin", "bobby pin", "hair ribbon",
    # 주얼리
    "ring", "bracelet", "necklace", "earring", "watch", "anklet",
    # 위생/뷰티
    "cotton swab", "toothbrush", "toothpaste", "shampoo", "soap",
    "razor", "nail clipper", "comb", "hair brush", "tweezers",
    "lotion", "sunscreen", "lipstick", "mascara", "perfume",
    "toner", "serum", "foundation", "hand cream", "contact lens",
    "cotton ball", "face mask", "band aid", "bandage",
    # 약/건강
    "vitamin", "pill", "capsule", "medicine",
    # 음식
    "apple", "banana", "orange", "grape", "strawberry", "watermelon",
    "peach", "mango", "bread", "milk", "egg", "rice", "noodle",
    "pasta", "ramen", "sushi", "dumpling", "hamburger", "sandwich",
    "pizza", "cake", "cookie", "chocolate", "candy",
    "chicken", "beef", "pork", "fish", "shrimp", "salmon",
    "carrot", "potato", "onion", "tomato", "lettuce", "broccoli",
    "mushroom", "garlic", "corn", "butter", "cheese", "yogurt",
    "kimchi", "tofu",
    # 음료
    "water bottle", "coffee", "juice", "soda", "beer", "wine",
    "tea", "milk tea", "smoothie", "energy drink",
    # 전자기기
    "smartphone", "laptop", "tablet", "keyboard", "computer mouse",
    "monitor", "charger", "power bank", "earphone", "headphone",
    "speaker", "camera", "remote control", "earbuds",
    # 의류/패션
    "shirt", "pants", "dress", "jacket", "coat", "shoes", "sneakers",
    "boots", "hat", "cap", "gloves", "scarf", "socks", "bag",
    "backpack", "handbag", "wallet", "belt", "sunglasses",
    # 문구
    "book", "notebook", "pen", "pencil", "eraser", "scissors",
    "tape", "ruler", "paper clip", "sticky note", "envelope",
    # 주방/가전
    "cup", "bowl", "plate", "pot", "pan", "spoon", "fork",
    "chopsticks", "knife", "cutting board", "water bottle",
    "microwave", "rice cooker", "electric kettle", "blender",
    # 세제/청소
    "dish soap", "laundry detergent", "fabric softener",
    "sponge", "broom", "vacuum cleaner",
    # 잡화
    "rubber band", "safety pin", "key", "umbrella", "candle",
    "toy", "shopping bag", "garbage bag", "toilet paper",
    "tissue", "plastic bag",
]

# 복합어(bigram) 우선 매칭 — 단어 순서 포함
KOREAN_BIGRAM_MAP: dict[str, str] = {
    "cotton swab": "면봉", "cotton ball": "솜뭉치", "water bottle": "물병",
    "toilet paper": "화장지", "tissue paper": "화장지", "paper towel": "종이타월",
    "toothbrush": "칫솔", "toothpaste": "치약", "nail clipper": "손톱깎이",
    "hair brush": "헤어브러시", "hair clip": "머리핀", "hair pin": "머리핀",
    "scrunchie": "슈크링",
    "face mask": "마스크", "rubber band": "고무줄",
    "sticky note": "포스트잇", "post it": "포스트잇",
    "cutting board": "도마", "plastic bag": "비닐봉지",
    "garbage bag": "쓰레기봉투", "trash bag": "쓰레기봉투",
    "hand cream": "핸드크림", "eye drop": "안약", "eye drops": "안약",
    "contact lens": "콘택트렌즈",
    "band aid": "반창고", "bandage": "붕대",
    "hot pack": "핫팩", "ice pack": "얼음팩",
    "dish soap": "주방세제", "laundry detergent": "세탁세제",
    "fabric softener": "섬유유연제",
    "solar charger": "태양광 충전기", "power bank": "보조배터리",
    "charging cable": "충전 케이블", "usb cable": "USB 케이블",
    "earphone": "이어폰", "ear bud": "이어폰", "ear buds": "이어폰",
    "smart phone": "스마트폰", "mobile phone": "휴대폰",
    "laptop computer": "노트북", "notebook computer": "노트북",
    "remote control": "리모컨", "air conditioner": "에어컨",
    "washing machine": "세탁기", "vacuum cleaner": "청소기",
    "coffee maker": "커피메이커", "rice cooker": "밥솥",
    "electric kettle": "전기주전자", "instant noodle": "라면",
    "ramen noodle": "라면", "cup noodle": "컵라면",
    "vitamin supplement": "비타민", "dietary supplement": "건강기능식품",
    "trash can": "쓰레기통", "waste bin": "쓰레기통",
    "shopping bag": "쇼핑백", "tote bag": "토트백",
    "running shoe": "운동화", "sports shoe": "운동화",
    "safety pin": "안전핀", "paper clip": "클립",
}

# 단어 단위 매칭
TOKEN_KOREAN_MAP: dict[str, str] = {
    # 위생/뷰티
    "cotton": "솜", "swab": "면봉", "qtip": "면봉", "shampoo": "샴푸",
    "soap": "비누", "razor": "면도기", "comb": "빗", "lotion": "로션",
    "sunscreen": "선크림", "lipstick": "립스틱", "mascara": "마스카라",
    "perfume": "향수", "toner": "토너", "serum": "세럼",
    "foundation": "파운데이션", "eyeshadow": "아이섀도", "tweezers": "핀셋",
    # 음식
    "apple": "사과", "banana": "바나나", "orange": "오렌지",
    "grape": "포도", "strawberry": "딸기", "watermelon": "수박",
    "peach": "복숭아", "mango": "망고", "bread": "빵", "milk": "우유",
    "egg": "달걀", "rice": "쌀/밥", "noodle": "면", "pasta": "파스타",
    "coffee": "커피", "juice": "주스", "pizza": "피자",
    "hamburger": "햄버거", "sandwich": "샌드위치", "sushi": "스시",
    "dumpling": "만두", "cake": "케이크", "cookie": "쿠키",
    "chocolate": "초콜릿", "candy": "사탕", "snack": "간식",
    "ramen": "라면", "kimchi": "김치", "tofu": "두부",
    "butter": "버터", "cheese": "치즈", "yogurt": "요거트",
    "chicken": "닭고기", "beef": "소고기", "pork": "돼지고기",
    "fish": "생선", "shrimp": "새우", "salmon": "연어",
    "carrot": "당근", "potato": "감자", "onion": "양파",
    "tomato": "토마토", "lettuce": "상추", "broccoli": "브로콜리",
    "mushroom": "버섯", "garlic": "마늘", "corn": "옥수수",
    # 음료
    "water": "물", "tea": "차", "soda": "탄산음료", "cola": "콜라",
    "beer": "맥주", "wine": "와인", "latte": "라떼",
    "americano": "아메리카노", "smoothie": "스무디",
    # 전자기기
    "phone": "휴대폰", "smartphone": "스마트폰", "laptop": "노트북",
    "computer": "컴퓨터", "tablet": "태블릿", "keyboard": "키보드",
    "mouse": "마우스", "monitor": "모니터", "screen": "화면",
    "charger": "충전기", "battery": "배터리", "remote": "리모컨",
    "headphone": "헤드폰", "earphone": "이어폰", "speaker": "스피커",
    "camera": "카메라", "television": "TV", "tv": "TV",
    # 의류/패션
    "shirt": "셔츠", "pants": "바지", "jeans": "청바지",
    "dress": "원피스", "skirt": "치마", "jacket": "재킷",
    "coat": "코트", "sweater": "스웨터", "shoes": "신발",
    "sneaker": "운동화", "boots": "부츠", "sandals": "샌들",
    "hat": "모자", "cap": "캡모자", "gloves": "장갑",
    "scarf": "스카프", "socks": "양말", "bag": "가방",
    "backpack": "백팩", "handbag": "핸드백", "wallet": "지갑",
    "belt": "벨트", "sunglasses": "선글라스", "watch": "시계",
    "ring": "반지", "necklace": "목걸이", "earring": "귀걸이",
    "bracelet": "팔찌", "band": "밴드/끈", "elastic": "고무줄",
    "scrunchie": "슈크링", "loop": "고리", "strap": "끈",
    # 가구/인테리어
    "table": "테이블", "desk": "책상", "chair": "의자",
    "sofa": "소파", "bed": "침대", "shelf": "선반",
    "lamp": "램프", "mirror": "거울", "curtain": "커튼",
    "pillow": "베개", "blanket": "담요", "carpet": "카펫",
    "room": "방",
    # 주방용품
    "pot": "냄비", "pan": "팬", "bowl": "그릇",
    "plate": "접시", "cup": "컵", "bottle": "병",
    "spoon": "숟가락", "fork": "포크", "knife": "칼",
    "chopstick": "젓가락", "oven": "오븐", "microwave": "전자레인지",
    "refrigerator": "냉장고", "blender": "블렌더",
    # 문구
    "book": "책", "notebook": "노트", "pen": "펜",
    "pencil": "연필", "eraser": "지우개", "scissors": "가위",
    "tape": "테이프", "ruler": "자", "paper": "종이",
    "envelope": "봉투",
    # 청소/세탁
    "detergent": "세제", "sponge": "스펀지", "broom": "빗자루",
    "vacuum": "청소기",
    # 약/건강
    "medicine": "약", "vitamin": "비타민", "pill": "알약",
    "capsule": "캡슐", "mask": "마스크",
    # 동물
    "dog": "강아지", "cat": "고양이", "bird": "새",
    "rabbit": "토끼", "hamster": "햄스터",
    # 식물
    "plant": "식물", "flower": "꽃", "tree": "나무",
    "cactus": "선인장", "rose": "장미",
    # 기타
    "key": "열쇠", "umbrella": "우산", "candle": "양초",
    "box": "상자", "toy": "장난감", "gift": "선물",
    "flashlight": "손전등", "can": "캔", "jar": "유리병",
    "person": "사람", "man": "남성", "woman": "여성",
}


def _ensure_nltk() -> None:
    pass  # CLIP 방식에서는 NLTK 불필요


def singularize(token: str) -> str:
    if len(token) > 4 and token.endswith("ies"):
        return token[:-3] + "y"
    if len(token) > 3 and token.endswith("es"):
        return token[:-2]
    if len(token) > 3 and token.endswith("s"):
        return token[:-1]
    return token


@lru_cache(maxsize=1)
def get_en_ko_translator():
    device_idx = 0 if torch.cuda.is_available() else -1
    return pipeline(
        "translation_en_to_ko",
        model="Helsinki-NLP/opus-mt-en-ko",
        device=device_idx,
    )


def translate_label_to_korean(label: str) -> str:
    """번역 실패 시에도 원래 영문을 반환 (라벨을 버리지 않음)."""
    key = label.strip().lower()
    if not key:
        return label

    # 1. bigram 맵 직접 매칭
    if key in KOREAN_BIGRAM_MAP:
        return KOREAN_BIGRAM_MAP[key]

    # 2. 단어 맵 매칭
    if key in TOKEN_KOREAN_MAP:
        return TOKEN_KOREAN_MAP[key]

    singular = singularize(key)
    if singular in TOKEN_KOREAN_MAP:
        return TOKEN_KOREAN_MAP[singular]

    # 3. 복합어를 토큰별로 조합
    parts = [p for p in re.sub(r"[^a-z0-9 ]", " ", key).split() if p]
    if len(parts) > 1:
        translated_parts: list[str] = []
        for p in parts:
            base = singularize(p)
            ko = TOKEN_KOREAN_MAP.get(p) or TOKEN_KOREAN_MAP.get(base)
            if ko:
                translated_parts.append(ko)
        if translated_parts:
            return " ".join(translated_parts)

    # 4. Helsinki 번역 모델 폴백
    try:
        translator = get_en_ko_translator()
        out = translator(key, max_length=64)
        if out and isinstance(out, list):
            translated = out[0].get("translation_text", "").strip()
            if translated:
                return translated
    except Exception:
        pass

    # 5. 마지막 폴백: 영문 그대로 반환 (라벨을 버리지 않음)
    return label


def classify_with_clip(image: Image.Image, top_k: int = 6) -> list[tuple[str, float]]:
    """CLIP zero-shot 분류. 반환값의 score는 softmax 확률(0~1)."""
    inputs = clip_processor(
        text=CANDIDATE_LABELS,
        images=image,
        return_tensors="pt",
        padding=True,
        truncation=True,
    ).to(device)

    with torch.no_grad():
        outputs = clip_model(**inputs)
        logits = outputs.logits_per_image[0]

    probs = logits.softmax(dim=0)
    top_indices = probs.topk(top_k).indices.tolist()
    return [(CANDIDATE_LABELS[i], probs[i].item()) for i in top_indices]


def caption_with_blip(image: Image.Image) -> list[str]:
    """BLIP으로 여러 프롬프트 캡션 생성 → 키워드 목록 반환."""
    prompts = [None, "there is a", "this is a photo of a"]
    captions: list[str] = []
    inputs_base = blip_processor(image, return_tensors="pt").to(device)
    for prompt in prompts:
        try:
            if prompt:
                inputs = blip_processor(image, text=prompt, return_tensors="pt").to(device)
            else:
                inputs = inputs_base
            with torch.no_grad():
                out = blip_model.generate(**inputs, max_new_tokens=50)
            caption = blip_processor.decode(out[0], skip_special_tokens=True)
            if prompt and caption.lower().startswith(prompt.lower()):
                caption = caption[len(prompt):].strip()
            if caption:
                captions.append(caption)
        except Exception:
            continue

    # 캡션에서 명사성 토큰 추출
    stopwords = {
        "a", "an", "the", "of", "on", "in", "with", "and", "to", "for",
        "is", "are", "it", "this", "that", "there", "photo", "picture",
        "image", "white", "black", "red", "blue", "green", "small", "large",
    }
    keywords: list[str] = []
    for caption in captions:
        for token in re.sub(r"[^a-z0-9 ]+", " ", caption.lower()).split():
            if len(token) >= 3 and token not in stopwords and token not in keywords:
                keywords.append(token)

    # bigram도 탐색
    all_tokens: list[str] = []
    for caption in captions:
        all_tokens += re.sub(r"[^a-z0-9 ]+", " ", caption.lower()).split()
    for i in range(len(all_tokens) - 1):
        bigram = f"{all_tokens[i]} {all_tokens[i+1]}"
        if bigram in KOREAN_BIGRAM_MAP and bigram not in keywords:
            keywords.insert(0, bigram)  # bigram 우선

    return keywords[:8]


@app.get("/health")
def health():
    return jsonify({"ok": True})


@app.post("/analyze")
def analyze():
    if "image" not in request.files:
        return jsonify({"error": "image field is required"}), 400

    image_file = request.files["image"]
    if image_file.filename == "":
        return jsonify({"error": "empty filename"}), 400

    try:
        image = Image.open(image_file.stream).convert("RGB")

        # ── 1단계: CLIP으로 후보 분류 ──────────────────────────
        clip_results = classify_with_clip(image, top_k=6)
        top_score = clip_results[0][1] if clip_results else 0.0

        labels = []
        seen: set[str] = set()

        if top_score >= CLIP_CONFIDENCE_THRESHOLD:
            # CLIP 결과 사용 (후보에 있는 물건)
            max_score = clip_results[0][1]
            for eng_label, raw_score in clip_results:
                korean = translate_label_to_korean(eng_label)
                if korean in seen:
                    continue
                seen.add(korean)
                labels.append({
                    "label": korean,
                    "score": round(raw_score / max_score, 4),
                })
        else:
            # ── 2단계: BLIP 폴백 (후보에 없는 물건) ─────────────
            keywords = caption_with_blip(image)
            for idx, kw in enumerate(keywords):
                korean = translate_label_to_korean(kw)
                if korean in seen:
                    continue
                seen.add(korean)
                labels.append({
                    "label": korean,
                    "score": max(0.4, 0.85 - idx * 0.07),
                })

        return jsonify({"labels": labels, "ocr_texts": []})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
