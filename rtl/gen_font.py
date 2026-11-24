"""
gen_font.py  --  8x16 bitmap font ROM for the on-screen status text

Renders printable ASCII 32..127 from the Windows Consolas font with Pillow
into 8x16 cells and writes rtl/mem/font8x16.mem (96 glyphs x 16 rows, one
hex byte per row, MSB = leftmost pixel). Prints a few glyphs as ASCII art so
the bitmaps can be checked by eye.

Run:  python rtl/gen_font.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "mem", "font8x16.mem")
FONT_CANDIDATES = [r"C:\Windows\Fonts\consolab.ttf", r"C:\Windows\Fonts\consola.ttf",
                   r"C:\Windows\Fonts\cour.ttf"]


def main() -> None:
    path = next(p for p in FONT_CANDIDATES if os.path.exists(p))
    font = ImageFont.truetype(path, 14)
    rows = []
    glyphs = {}
    for code in range(32, 128):
        img = Image.new("L", (8, 16), 0)
        d = ImageDraw.Draw(img)
        ch = chr(code) if code < 127 else " "
        d.text((0, 0), ch, fill=255, font=font)
        px = img.load()
        g = []
        for y in range(16):
            v = 0
            for x in range(8):
                if px[x, y] > 110:
                    v |= 1 << (7 - x)
            g.append(v)
        glyphs[ch] = g
        rows.extend(g)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        fh.write("\n".join(f"{v:02x}" for v in rows) + "\n")
    print(f"font from {path}: {len(rows)} rows -> {OUT}")
    for ch in "P17A":
        print(f"--- {ch}")
        for v in glyphs[ch]:
            print("".join("#" if v & (1 << (7 - x)) else "." for x in range(8)))


if __name__ == "__main__":
    main()
