from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ASSETS.mkdir(exist_ok=True)

SCALE = 4
SIZE = 256
CANVAS = SIZE * SCALE


def make_icon(enabled: bool) -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def scaled(values):
        return tuple(value * SCALE for value in values)

    color = (0, 145, 105, 255) if enabled else (95, 103, 112, 255)
    border = (0, 105, 75, 255) if enabled else (65, 72, 80, 255)
    draw.ellipse(scaled((8, 8, 248, 248)), fill=color, outline=border, width=8 * SCALE)

    if enabled:
        points = [(56, 132), (105, 181), (201, 76)]
        draw.line(
            [scaled(point) for point in points],
            fill=(255, 255, 255, 255),
            width=27 * SCALE,
            joint="curve",
        )
    else:
        draw.line(
            [scaled((75, 75)), scaled((181, 181))],
            fill=(255, 255, 255, 255),
            width=27 * SCALE,
        )
        draw.line(
            [scaled((181, 75)), scaled((75, 181))],
            fill=(255, 255, 255, 255),
            width=27 * SCALE,
        )

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_app_icon() -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def scaled(values):
        return tuple(value * SCALE for value in values)

    draw.rounded_rectangle(
        scaled((8, 8, 248, 248)),
        radius=56 * SCALE,
        fill=(31, 96, 145, 255),
        outline=(20, 68, 107, 255),
        width=8 * SCALE,
    )

    white = (255, 255, 255, 255)
    cyan = (173, 232, 244, 255)
    blue = (31, 96, 145, 255)

    # Two endpoints with a proxy server in the middle.
    for bounds in ((31, 101, 84, 151), (172, 101, 225, 151)):
        draw.rounded_rectangle(scaled(bounds), radius=7 * SCALE, fill=white)
        draw.rectangle(scaled((bounds[0] + 8, 110, bounds[2] - 8, 138)), fill=blue)
        draw.rectangle(scaled((bounds[0] + 21, 153, bounds[2] - 21, 160)), fill=white)

    draw.rounded_rectangle(scaled((104, 91, 152, 165)), radius=8 * SCALE, fill=white)
    for y in (106, 127, 148):
        draw.ellipse(scaled((114, y - 4, 122, y + 4)), fill=blue)
        draw.line(scaled((130, y, 141, y)), fill=blue, width=4 * SCALE)

    # Bidirectional routing arrows represent switching traffic through a proxy.
    draw.line(scaled((65, 73, 190, 73)), fill=cyan, width=12 * SCALE)
    draw.polygon([scaled((190, 73)), scaled((163, 52)), scaled((163, 94))], fill=cyan)
    draw.line(scaled((191, 183, 66, 183)), fill=cyan, width=12 * SCALE)
    draw.polygon([scaled((66, 183)), scaled((93, 162)), scaled((93, 204))], fill=cyan)

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


for enabled, name in ((True, "proxy-on"), (False, "proxy-off")):
    icon = make_icon(enabled)
    icon.save(ASSETS / f"{name}.png")
    icon.save(
        ASSETS / f"{name}.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

app_icon = make_app_icon()
app_icon.save(ASSETS / "app-icon.png")
app_icon.save(
    ASSETS / "app-icon.ico",
    format="ICO",
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
