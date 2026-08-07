from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/google_play/source"
TEMPLATE = SOURCE / "feature_graphic_template.png"
SCREENSHOT = SOURCE / "phone/login_light.png"
DESTINATION = ROOT / "assets/google_play/feature_graphic.png"


canvas = Image.open(TEMPLATE).convert("RGBA")
screenshot = Image.open(SCREENSHOT).convert("RGB")

# The login screen has no controls under the Flutter DEBUG ribbon.
background = screenshot.getpixel((screenshot.width - 120, 8))
ImageDraw.Draw(screenshot).rectangle(
    (screenshot.width - 105, 0, screenshot.width - 1, 105),
    fill=background,
)

screen_box = (624, 69, 800, 424)
screen_size = (
    screen_box[2] - screen_box[0],
    screen_box[3] - screen_box[1],
)
screenshot = screenshot.resize(screen_size, Image.Resampling.LANCZOS).convert("RGBA")

mask = Image.new("L", screen_size, 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, screen_size[0] - 1, screen_size[1] - 1),
    radius=9,
    fill=255,
)
canvas.paste(screenshot, screen_box[:2], mask)

canvas.convert("RGB").save(DESTINATION, optimize=True)
print(f"{DESTINATION}: {canvas.size}, {DESTINATION.stat().st_size} bytes")
