# Crops the status bar and draws numbered red boxes/circles on README screenshots.
import sys
from PIL import Image, ImageDraw, ImageFont
RED = (235, 40, 50)
def font(sz):
    for f in ("/system/fonts/Roboto-Bold.ttf", "/system/fonts/RobotoStatic-Regular.ttf", "/system/fonts/DroidSans-Bold.ttf"):
        try: return ImageFont.truetype(f, sz)
        except Exception: pass
    return ImageFont.load_default()
def badge(d, x, y, n):
    r = 46
    d.ellipse((x-r, y-r, x+r, y+r), fill=RED, outline="white", width=6)
    f = font(56); w = d.textlength(str(n), font=f)
    d.text((x - w/2, y - 34), str(n), fill="white", font=f)
def annotate(src, out, marks, crop_top=130, crop=None, label=None):
    im = Image.open(src).convert("RGB")
    d = ImageDraw.Draw(im)
    for m in marks:
        kind, n, box = m
        if kind == "box":
            d.rounded_rectangle(box, radius=36, outline=RED, width=12)
            badge(d, box[0] + 10, box[1] + 10, n)
        else:  # circle: box = (cx, cy, r)
            cx, cy, r = box
            d.ellipse((cx-r, cy-r, cx+r, cy+r), outline=RED, width=12)
            badge(d, cx + r - 10, cy - r + 10, n)
    top = crop_top
    im = im.crop(crop if crop else (0, top, im.width, im.height))
    if label:
        bar = Image.new("RGB", (im.width, 120), RED); bd = ImageDraw.Draw(bar)
        f = font(54); bd.text((40, 30), label, fill="white", font=f)
        new = Image.new("RGB", (im.width, im.height + 120)); new.paste(bar, (0, 0)); new.paste(im, (0, 120)); im = new
    im.thumbnail((720, 1600))
    im.save(out, optimize=True)
    print("wrote", out, im.size)
