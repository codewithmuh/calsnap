"""
Claude vision: meal photo -> nutrition JSON.

This is the heart of CalSnap. Keep it readable — it's on-screen content.
"""
import base64
import json
import logging

from anthropic import Anthropic
from django.conf import settings

logger = logging.getLogger(__name__)

# The one prompt that does the magic. Strict JSON, no prose.
SYSTEM_PROMPT = """You are a nutrition estimation engine for a calorie-tracking app.
You receive a single photo of a meal. Identify the food and estimate its nutrition
for the portion that is actually visible in the image.

Respond with ONLY a JSON object — no markdown, no code fences, no commentary —
with exactly these keys:

{
  "food": string,        // short human name, e.g. "Grilled chicken with rice and broccoli"
  "calories": integer,   // total kcal for the visible portion
  "protein_g": integer,  // grams of protein
  "carbs_g": integer,    // grams of carbohydrate
  "fat_g": integer,      // grams of fat
  "confidence": number   // 0.0-1.0, how sure you are
}

Rules:
- Estimate realistic values for the portion shown. Do not return zeros unless the
  plate is genuinely empty.
- If the image is not food, return food "Not a meal", all macros 0, confidence 0.0.
- Round macros to whole grams and calories to whole numbers.
- Output must be valid JSON parseable by json.loads. Nothing else."""

# Map common file extensions / content to a media type Claude accepts.
_MEDIA_TYPES = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG": "image/png",
    b"GIF8": "image/gif",
    b"RIFF": "image/webp",
}


def _detect_media_type(image_bytes: bytes) -> str:
    for sig, mt in _MEDIA_TYPES.items():
        if image_bytes.startswith(sig):
            return mt
    return "image/jpeg"


class ClaudeError(Exception):
    """Raised when Claude fails or returns unparseable output."""


def analyze_meal(image_bytes: bytes, note: str = "") -> dict:
    """Send a meal image to Claude vision and return validated nutrition dict.

    Returns: {food, calories, protein_g, carbs_g, fat_g, confidence}
    Raises ClaudeError on API failure or bad JSON.
    """
    if not settings.ANTHROPIC_API_KEY:
        raise ClaudeError("ANTHROPIC_API_KEY is not configured.")

    client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    media_type = _detect_media_type(image_bytes)
    b64 = base64.standard_b64encode(image_bytes).decode("ascii")

    user_text = "Analyze this meal."
    if note:
        user_text += f" User note: {note}"

    try:
        message = client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": b64,
                            },
                        },
                        {"type": "text", "text": user_text},
                    ],
                }
            ],
        )
    except Exception as exc:  # network / API / auth errors
        logger.exception("Claude API call failed")
        raise ClaudeError(f"Claude API call failed: {exc}") from exc

    raw = "".join(block.text for block in message.content if block.type == "text").strip()
    return _parse_and_validate(raw)


def _parse_and_validate(raw: str) -> dict:
    """Parse Claude's text into a clean nutrition dict, tolerating stray fences."""
    text = raw.strip()
    if text.startswith("```"):
        # strip ```json ... ``` fencing just in case
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
        text = text.strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        logger.error("Could not parse Claude output: %r", raw)
        raise ClaudeError("Claude returned invalid JSON.") from exc

    try:
        result = {
            "food": str(data["food"])[:200],
            "calories": max(0, int(round(float(data["calories"])))),
            "protein_g": max(0, int(round(float(data["protein_g"])))),
            "carbs_g": max(0, int(round(float(data["carbs_g"])))),
            "fat_g": max(0, int(round(float(data["fat_g"])))),
            "confidence": max(0.0, min(1.0, float(data.get("confidence", 0.5)))),
        }
    except (KeyError, TypeError, ValueError) as exc:
        logger.error("Claude JSON missing fields: %r", data)
        raise ClaudeError("Claude JSON missing required fields.") from exc

    return result
