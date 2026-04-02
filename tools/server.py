from flask import Flask, jsonify, request
import re
from functools import lru_cache
from PIL import Image
from transformers import BlipProcessor, BlipForConditionalGeneration, pipeline
import torch

app = Flask(__name__)

# BLIP 모델로 이미지 설명 생성
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32
processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
model = BlipForConditionalGeneration.from_pretrained(
    "Salesforce/blip-image-captioning-base", 
    torch_dtype=dtype
).to(device)

KEYWORD_STOPWORDS = {
    "a", "an", "the", "of", "on", "in", "with", "and", "to", "for", "at",
    "is", "are", "this", "that", "it", "photo", "picture", "image", "there",
}

TOKEN_KOREAN_MAP = {
    "cotton": "면", "swab": "면봉", "qtip": "면봉", "mouse": "마우스",
    "table": "테이블", "desk": "책상", "phone": "휴대폰", "laptop": "노트북",
    "book": "책", "notebook": "노트", "pen": "펜", "bottle": "병",
    "cup": "컵", "plate": "접시", "keyboard": "키보드", "screen": "화면",
    "monitor": "모니터", "person": "사람", "man": "남성", "woman": "여성",
    "dog": "강아지", "cat": "고양이", "chair": "의자", "room": "방",
}


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


def translate_label_to_korean(label: str) -> str | None:
    key = label.strip().lower()
    if not key:
        return None

    if key in TOKEN_KOREAN_MAP:
        return TOKEN_KOREAN_MAP[key]

    singular = singularize(key)
    if singular in TOKEN_KOREAN_MAP:
        return TOKEN_KOREAN_MAP[singular]

    parts = [p for p in key.replace("-", " ").split() if p]
    if parts:
        translated_parts: list[str] = []
        for p in parts:
            base = singularize(p)
            ko = TOKEN_KOREAN_MAP.get(p) or TOKEN_KOREAN_MAP.get(base)
            if not ko:
                translated_parts = []
                break
            translated_parts.append(ko)
        if translated_parts:
            return " ".join(translated_parts)

    try:
        translator = get_en_ko_translator()
        out = translator(key, max_length=64)
        if out and isinstance(out, list):
            translated = out[0].get("translation_text", "").strip()
            if translated:
                return translated
    except Exception:
        pass

    return None


def extract_keywords(caption: str, limit: int = 5) -> list[str]:
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

        # BLIP로 이미지 설명 생성
        inputs = processor(image, return_tensors="pt").to(device)
        with torch.no_grad():
            out = model.generate(**inputs, max_length=100)
        caption = processor.decode(out[0], skip_special_tokens=True)

        keywords = extract_keywords(caption, limit=5)
        if not keywords and caption.strip():
            keywords = [caption.strip().split()[-1].lower()]

        labels = []
        for idx, keyword in enumerate(keywords):
            translated = translate_label_to_korean(keyword)
            if not translated:
                continue
            labels.append(
                {
                    "label": translated,
                    "score": max(0.5, 0.95 - idx * 0.1),
                }
            )

        return jsonify({
            "labels": labels,
            "ocr_texts": [],
        })
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    # Android emulator uses 10.0.2.2 to reach host localhost.
    app.run(host="0.0.0.0", port=5000, debug=False)
