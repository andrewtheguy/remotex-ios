# Renders Assets.xcassets/AppIcon.appiconset/icon.png (1024x1024).
#
#   uv run --with pillow scripts/render-icon.py
#
# No text and no font dependency: a bright screen with a second one behind it,
# which is the whole of what this app is.
from pathlib import Path

from PIL import Image, ImageDraw

S = 1024
BG = (17, 20, 24)
BACK = (58, 72, 90)
FRONT = (232, 238, 245)
ACCENT = (86, 160, 255)

img = Image.new("RGB", (S, S), BG)
d = ImageDraw.Draw(img)

# The remote screen, behind and to the upper right.
d.rounded_rectangle((330, 210, 880, 580), radius=36, fill=BACK)

# The screen in front: this device.
d.rounded_rectangle((150, 330, 720, 720), radius=44, fill=FRONT)
d.rounded_rectangle((150, 330, 720, 720), radius=44, outline=BG, width=18)

# The connection: one accent bar across the near screen's foot.
d.rounded_rectangle((280, 780, 590, 812), radius=16, fill=ACCENT)

out = Path(__file__).resolve().parent.parent / "Sources/RemotexApp/Assets.xcassets/AppIcon.appiconset/icon.png"
img.save(out)
print(f"wrote {out}")
