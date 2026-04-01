from flask import Flask, jsonify, request
import re
from PIL import Image
from transformers import BlipProcessor, BlipForConditionalGeneration
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

        labels = [
            {"label": keyword, "score": max(0.5, 0.95 - idx * 0.1)}
            for idx, keyword in enumerate(keywords)
        ]

        return jsonify({
            "labels": labels,
            "ocr_texts": [],
        })
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    # Android emulator uses 10.0.2.2 to reach host localhost.
    app.run(host="0.0.0.0", port=5000, debug=False)
