"""
label_image.py — BLIP 이미지 캡셔닝으로 정확한 물체 인식

사용법:
    python label_image.py <이미지 경로>           # BLIP으로 이미지 설명 생성
    python label_image.py <이미지 경로> --check   # 면봉인지 아닌지만 판단 (CLIP)

예시:
    python label_image.py photo.jpg
    python label_image.py photo.jpg --check

의존성 설치:
    pip install transformers Pillow torch torchvision
    
설명:
    - BLIP: 이미지에 대한 자세한 설명 생성 (예: "a white wireless mouse on desk")
    - --check: 면봉 여부 판단 (별도 zero-shot CLIP 사용)
"""

import sys
import re
from pathlib import Path
from PIL import Image
from transformers import pipeline, BlipProcessor, BlipForConditionalGeneration
import torch

KOREAN_MAP = {
    "cotton swab": "면봉", "cotton ball": "솜뭉치", "bandage": "붕대",
    "toothbrush": "칫솔", "toothpaste": "치약", "shampoo": "샴푸",
    "soap": "비누", "razor": "면도기", "comb": "빗",
    "nail clipper": "손톱깎이", "lotion": "로션", "sunscreen": "선크림",
    "lipstick": "립스틱", "mascara": "마스카라",
    "apple": "사과", "banana": "바나나", "bread": "빵", "milk": "우유",
    "egg": "달걀", "rice": "쌀/밥", "noodle": "면", "coffee": "커피",
    "juice": "주스", "water bottle": "물병", "pizza": "피자",
    "hamburger": "햄버거", "scissors": "가위", "pen": "펜",
    "notebook": "노트", "book": "책", "tape": "테이프",
    "envelope": "봉투", "key": "열쇠", "umbrella": "우산",
    "candle": "양초", "box": "상자", "phone": "휴대폰",
    "laptop": "노트북", "charger": "충전기", "headphones": "헤드폰",
    "camera": "카메라", "shoes": "신발", "bag": "가방",
    "watch": "시계", "glasses": "안경", "hat": "모자",
    "sponge": "스펀지", "detergent": "세제", "pot": "냄비",
    "cup": "컵", "plate": "접시", "knife": "칼/나이프",
}

BLIP_MODEL = "Salesforce/blip-image-captioning-base"  # 이미지를 자세히 설명하는 모델

KEYWORD_STOPWORDS = {
    "a", "an", "the", "of", "on", "in", "with", "and", "to", "for", "at",
    "is", "are", "this", "that", "it", "photo", "picture", "image", "there",
}

# 면봉 이진 판단용: 긍정/부정 문장 쌍
COTTON_SWAB_POSITIVE = [
    "a photo of a cotton swab",
    "a cotton swab or q-tip",
    "a white cotton swab stick",
]
COTTON_SWAB_NEGATIVE = [
    "a photo of something else",
    "this is not a cotton swab",
]

IS_COTTON_SWAB_THRESHOLD = 0.60  # 60% 이상이면 면봉으로 판단


def _translate_label(label: str) -> str:
    """영문 라벨을 한국어로 바꾸고, 없으면 원문을 반환합니다."""
    key = label.strip().lower()
    for en, ko in KOREAN_MAP.items():
        if en.lower() == key:
            return ko
    return label


def _extract_keywords(caption: str, limit: int = 3) -> list[str]:
    """BLIP 설명문에서 핵심 단어만 추출합니다."""
    tokens = re.sub(r"[^a-zA-Z0-9 ]+", " ", caption.lower()).split()
    keywords: list[str] = []
    for token in tokens:
        if token in KEYWORD_STOPWORDS or len(token) < 3:
            continue
        if token not in keywords:
            keywords.append(token)
        if len(keywords) >= max(1, limit):
            break
    return keywords


def check_cotton_swab(image_path: str) -> None:
    """이미지가 면봉인지 아닌지만 판단합니다."""
    path = Path(image_path)
    if not path.exists():
        print(f"[오류] 파일을 찾을 수 없습니다: {image_path}")
        sys.exit(1)

    print(f"\n이미지 로드 중: {path.name}")
    image = Image.open(path).convert("RGB")

    print("모델 로딩 중 (첫 실행 시 다운로드 약 350MB)...")
    classifier = pipeline(
        "zero-shot-image-classification",
        model="openai/clip-vit-base-patch32",
    )

    print("면봉 여부 분석 중...\n")

    # 긍정 문장들과의 평균 유사도 계산
    all_labels = COTTON_SWAB_POSITIVE + COTTON_SWAB_NEGATIVE
    results = classifier(image, candidate_labels=all_labels)

    score_map = {r["label"]: r["score"] for r in results}

    positive_score = sum(score_map.get(l, 0) for l in COTTON_SWAB_POSITIVE) / len(COTTON_SWAB_POSITIVE)
    negative_score = sum(score_map.get(l, 0) for l in COTTON_SWAB_NEGATIVE) / len(COTTON_SWAB_NEGATIVE)

    # 정규화: 긍정/(긍정+부정)
    total = positive_score + negative_score
    confidence = positive_score / total if total > 0 else 0.0

    print(f"{'항목':<20} {'점수':>8}")
    print("-" * 30)
    print(f"{'면봉일 확률':<20} {confidence * 100:>7.1f}%")
    print(f"{'면봉 아닐 확률':<20} {(1 - confidence) * 100:>7.1f}%")
    print()

    if confidence >= IS_COTTON_SWAB_THRESHOLD:
        print(f"✅ 판정: 면봉입니다 (신뢰도 {confidence * 100:.1f}%)")
    else:
        print(f"❌ 판정: 면봉이 아닙니다 (면봉 확률 {confidence * 100:.1f}%)")
        print("   → IS_COTTON_SWAB_THRESHOLD 값을 낮추면 더 느슨하게 판단합니다.")


def recognize(image_path: str, top_k: int = 5) -> None:
    path = Path(image_path)
    if not path.exists():
        print(f"[오류] 파일을 찾을 수 없습니다: {image_path}")
        sys.exit(1)

    print(f"\n이미지 로드 중: {path.name}")
    image = Image.open(path).convert("RGB")

    print("모델 로딩 중 (첫 실행 시 다운로드가 발생할 수 있습니다)...")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    processor = BlipProcessor.from_pretrained(BLIP_MODEL)
    model = BlipForConditionalGeneration.from_pretrained(
        BLIP_MODEL, torch_dtype=dtype
    ).to(device)

    print("분석 중...\n")

    # BLIP 설명을 키워드로 요약해서 반환
    inputs = processor(image, return_tensors="pt").to(device)
    with torch.no_grad():
        out = model.generate(**inputs, max_length=100)

    caption = processor.decode(out[0], skip_special_tokens=True)
    keywords = _extract_keywords(caption, limit=top_k)
    if not keywords and caption.strip():
        keywords = [caption.strip().split()[-1].lower()]

    if not keywords:
        print("핵심 키워드를 찾지 못했습니다.")
        return

    keywords_ko = [_translate_label(k) for k in keywords]
    print("핵심 키워드: " + ", ".join(keywords_ko))
    print()
    print(f"→ 앱에 입력될 라벨: [{keywords_ko[0]}]")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("사용법: python label_image.py <이미지 경로> [--check]")
        print("예시:  python label_image.py photo.jpg")
        print("       python label_image.py photo.jpg --check  # 면봉 여부만 판단")
        sys.exit(1)

    image_arg = sys.argv[1]
    mode_check = "--check" in sys.argv

    if mode_check:
        check_cotton_swab(image_arg)
    else:
        recognize(image_arg)
