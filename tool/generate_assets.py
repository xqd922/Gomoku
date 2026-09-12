"""Regenerate original code-drawn app icons and a soft stone sound.

Development-only dependency: Pillow (pip install Pillow).
"""
from pathlib import Path
import json
import math
import random
import struct
import wave

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parents[1] / "apps" / "gomoku_app"
random.seed(37)
audio_path = APP / "assets/sounds/stone.wav"
audio_path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(audio_path), "wb") as sound:
    sound.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
    samples = []
    for i in range(4410):
        t = i / 44100
        envelope = math.exp(-t * 95) * min(1, t / .0008)
        value = (math.sin(t * 2 * math.pi * 880) * .38
                 + math.sin(t * 2 * math.pi * 1320) * .16
                 + random.uniform(-1, 1) * .25) * envelope
        samples.append(struct.pack("<h", round(value * 22000)))
    sound.writeframes(b"".join(samples))

canvas = Image.new("RGB", (1024, 1024), "#eee5ff")
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((158, 158, 866, 866), radius=166, fill="#7960bc")
for offset in (342, 512, 682):
    draw.line((292, offset, 732, offset), fill="#a995d0", width=8)
    draw.line((offset, 292, offset, 732), fill="#a995d0", width=8)
for x, y, fill in [
    (342, 342, "#302938"), (512, 342, "#fffbff"),
    (512, 512, "#302938"), (342, 682, "#fffbff"), (682, 682, "#302938")
]:
    draw.ellipse((x - 66, y - 60, x + 66, y + 72), fill="#5f489b")
    draw.ellipse((x - 65, y - 65, x + 65, y + 65), fill=fill)
draw.ellipse((670, 670, 694, 694), fill="#d9c5ff")

def save_icon(path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.resize((size, size), Image.Resampling.LANCZOS).save(path)

for density, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    save_icon(APP / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
for platform in ("ios", "macos"):
    icons = APP / platform / "Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((icons / "Contents.json").read_text())
    for icon in contents["images"]:
        if "filename" in icon:
            size = round(float(icon["size"].split("x")[0]) * float(icon["scale"].rstrip("x")))
            save_icon(icons / icon["filename"], size)
for size in (192, 512):
    save_icon(APP / f"web/icons/Icon-{size}.png", size)
    save_icon(APP / f"web/icons/Icon-maskable-{size}.png", size)
save_icon(APP / "web/favicon.png", 64)
save_icon(APP / "linux/gomoku.png", 256)
canvas.save(APP / "windows/runner/resources/app_icon.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
print("Generated six-platform icons and stone.wav.")
