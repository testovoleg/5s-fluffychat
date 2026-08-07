from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/google_play/source"

PHONE_LIGHT = SOURCE / "phone/login_light.png"
PHONE_DARK = SOURCE / "phone/login_dark.png"
PHONE_CHATS = SOURCE / "phone/chat_list.png"

TABLET_LIGHT = SOURCE / "tablet/login_light.png"
TABLET_DARK = SOURCE / "tablet/login_dark.png"
TABLET_CHATS = SOURCE / "tablet/chat_list.png"


def alpha_crop(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    return image.crop(image.getchannel("A").getbbox())


logo = alpha_crop(ROOT / "assets/logo/img/logo_foreground.png")
wordmark = alpha_crop(ROOT / "assets/logo/img/logo_font.png")


def remove_debug(image: Image.Image, *, chat: bool) -> Image.Image:
    image = image.convert("RGB")
    width, height = image.size
    draw = ImageDraw.Draw(image)
    if not chat:
        background = image.getpixel((width - 120, 8))
        draw.rectangle((width - 105, 0, width - 1, 105), fill=background)
        return image

    if width < 600:
        center_x, center_y, radius = 450, 48, 23
        page_background = image.getpixel((400, 100))
        pill_color = image.getpixel((400, 30))
        pill_rectangle = (380, 14, 449, 75)
        pill_cap = (418, 14, 479, 75)
        font_size = 18
    else:
        center_x, center_y, radius = 728, 38, 20
        page_background = image.getpixel((650, 10))
        pill_color = image.getpixel((650, 30))
        pill_rectangle = (620, 10, 718, 62)
        pill_cap = (692, 10, 744, 62)
        font_size = 16

    draw = ImageDraw.Draw(image)
    draw.rectangle((width - 105, 0, width - 1, 105), fill=page_background)
    draw.rectangle(pill_rectangle, fill=pill_color)
    draw.ellipse(pill_cap, fill=pill_color)
    draw.ellipse(
        (
            center_x - radius,
            center_y - radius,
            center_x + radius,
            center_y + radius,
        ),
        fill=(153, 239, 137),
    )
    font = ImageFont.truetype("DejaVuSans.ttf", font_size)
    draw.text(
        (center_x, center_y),
        "5",
        font=font,
        fill=(38, 76, 42),
        anchor="mm",
    )
    return image


def add_header(canvas: Image.Image, logo_width: int, logo_y: int, word_width: int, word_y: int):
    mark = logo.resize(
        (logo_width, round(logo.height * logo_width / logo.width)),
        Image.Resampling.LANCZOS,
    )
    canvas.alpha_composite(mark, ((canvas.width - mark.width) // 2, logo_y))

    text = wordmark.resize(
        (word_width, round(wordmark.height * word_width / wordmark.width)),
        Image.Resampling.LANCZOS,
    )
    canvas.alpha_composite(text, ((canvas.width - text.width) // 2, word_y))


def add_device(
    canvas: Image.Image,
    screenshot: Image.Image,
    screen_box,
    outer_box,
    radius: int,
):
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    offset_box = (
        outer_box[0],
        outer_box[1] + radius // 3,
        outer_box[2],
        outer_box[3] + radius // 3,
    )
    shadow_draw.rounded_rectangle(offset_box, radius=radius, fill=(0, 0, 0, 75))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius // 2))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(outer_box, radius=radius, fill=(20, 22, 24))
    draw.rounded_rectangle(
        (
            outer_box[0] + 8,
            outer_box[1] + 8,
            outer_box[2] - 8,
            outer_box[3] - 8,
        ),
        radius=max(1, radius - 6),
        outline=(68, 72, 78),
        width=3,
    )

    left, top, right, bottom = screen_box
    screen_size = (right - left, bottom - top)
    screen = screenshot.resize(screen_size, Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", screen_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen_size[0] - 1, screen_size[1] - 1),
        radius=max(16, radius - 16),
        fill=255,
    )
    canvas.paste(screen, (left, top), mask)


def build(
    source_path: Path,
    destination: Path,
    output_size,
    screen_box,
    outer_box,
    radius,
    header,
    *,
    chat: bool,
):
    destination.parent.mkdir(parents=True, exist_ok=True)
    screenshot = remove_debug(Image.open(source_path), chat=chat)
    canvas = Image.new("RGBA", output_size, "white")
    add_header(canvas, *header)
    add_device(canvas, screenshot, screen_box, outer_box, radius)
    canvas.convert("RGB").save(destination, optimize=True)
    print(f"{destination}: {canvas.size}, {destination.stat().st_size} bytes")


phone_destination = ROOT / "assets/google_play/publish/phone"
tablet_7_destination = ROOT / "assets/google_play/publish/tablet_7"
tablet_10_destination = ROOT / "assets/google_play/publish/tablet_10"

for filename, source, chat in (
    ("01_login_light.png", PHONE_LIGHT, False),
    ("02_login_dark.png", PHONE_DARK, False),
    ("03_chat_list.png", PHONE_CHATS, True),
):
    build(
        source,
        phone_destination / filename,
        (1080, 1920),
        (190, 460, 890, 1899),
        (165, 425, 915, 1920),
        62,
        (190, 36, 340, 262),
        chat=chat,
    )

for filename, source, chat in (
    ("01_login_light.png", TABLET_LIGHT, False),
    ("02_login_dark.png", TABLET_DARK, False),
    ("03_chat_list.png", TABLET_CHATS, True),
):
    build(
        source,
        tablet_7_destination / filename,
        (1080, 1920),
        (80, 560, 1000, 1787),
        (42, 515, 1038, 1832),
        48,
        (205, 38, 350, 276),
        chat=chat,
    )
    build(
        source,
        tablet_10_destination / filename,
        (1440, 2560),
        (90, 720, 1350, 2400),
        (42, 660, 1398, 2460),
        62,
        (275, 52, 470, 370),
        chat=chat,
    )
