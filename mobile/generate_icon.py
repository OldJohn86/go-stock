#!/usr/bin/env python3
"""
go-stock App Icon Generator — redesign v3
Design: Clean fintech logo with Chinese market colors (red=up, green=down).
Simpler, bolder, more modern.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

OUTPUT_DIR = "/Users/jonathanchen/gitee/github/go-stock/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
BASE_SIZE = 1024

# ── brand colors: Chinese market convention ─────────────
# red = up (涨), green = down (跌)
BRAND_BLUE    = (25, 118, 210)    # #1976D2 — primary
BRAND_DARK    = (13, 25, 50)      # deep navy bg
BRAND_LIGHT   = (66, 165, 245)    # accent blue
CANDLE_UP     = (244, 67, 54)     # red = 涨
CANDLE_DOWN   = (0, 200, 83)      # green = 跌
WHITE         = (255, 255, 255)
SOFT_WHITE    = (210, 220, 240)

# ── helpers ───────────────────────────────────────────────

def _font(paths, size):
    for fp in paths:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, int(size))
    return ImageFont.load_default()


def ver_gradient(w, h, colors):
    """Vertical multi-stop gradient."""
    img = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(img)
    stops = len(colors)
    for y in range(h):
        t = y / (h - 1) * (stops - 1)
        idx = int(t)
        frac = t - idx
        c1, c2 = colors[min(idx, stops - 2)], colors[min(idx + 1, stops - 1)]
        r = int(c1[0] + (c2[0] - c1[0]) * frac)
        g = int(c1[1] + (c2[1] - c1[1]) * frac)
        b = int(c1[2] + (c2[2] - c1[2]) * frac)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def glow_bloom(base, cx, cy, r, color, steps=40):
    """Radial glow via concentric ellipses into a new layer."""
    g = Image.new("RGBA", (base.width, base.height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for s in range(steps, 0, -2):
        a = int(180 * math.exp(-((s / steps) ** 2) * 3))
        gd.ellipse(
            [cx - s * r // steps, cy - s * r // steps,
             cx + s * r // steps, cy + s * r // steps],
            fill=(color[0], color[1], color[2], min(a, color[3])))
    return Image.alpha_composite(base, g)


def draw_candle(draw, cx, body_top, body_bottom, wick_top, wick_bottom, color, w=12):
    """Draw a single candlestick with wick and rounded body."""
    # Wick
    draw.line([(cx, wick_top), (cx, wick_bottom)], fill=color, width=3)

    # Body rounded rect
    body_h = max(body_bottom - body_top, 4)
    draw.rounded_rectangle(
        [cx - w // 2, body_top, cx + w // 2, body_bottom],
        radius=3, fill=color
    )

    # Highlight line on body for depth
    hl_color = (min(color[0] + 60, 255), min(color[1] + 60, 255), min(color[2] + 60, 255))
    draw.rounded_rectangle(
        [cx - w // 2 + 2, body_top + 2, cx + w // 2 - 2, body_top + body_h // 3],
        radius=2, fill=hl_color
    )


# ── main icon ──────────────────────────────────────────────

def create_icon():
    S = BASE_SIZE
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # ── 1. Gradient background: deep navy → blue ───────────
    bg = ver_gradient(S, S, [
        (10, 20, 45),        # deep navy
        (15, 35, 75),        # dark blue
        (25, 80, 160),       # mid blue
        (25, 118, 210),      # brand blue
    ])
    img.paste(bg, (0, 0))

    # ── 2. Subtle center glow ───────────────────────────────
    img = glow_bloom(img, S // 2, S // 2, int(S * 0.45),
                     (66, 165, 245, 35), 45)

    # ── 3. Main card ────────────────────────────────────────
    m = int(S * 0.16)
    cx0, cy0 = m, int(S * 0.14)
    cx1, cy1 = S - m, int(S * 0.60)
    cr = int(S * 0.10)

    card = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(card)
    # Card fill (frosted glass)
    cdraw.rounded_rectangle([cx0, cy0, cx1, cy1], radius=cr,
                            fill=(255, 255, 255, 22))
    # Card border
    cdraw.rounded_rectangle([cx0, cy0, cx1, cy1], radius=cr,
                            outline=(255, 255, 255, 30), width=2)
    img = Image.alpha_composite(img, card)

    # Card mask for chart clipping
    card_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(card_mask).rounded_rectangle(
        [cx0, cy0, cx1, cy1], radius=cr, fill=255)

    # ── 4. Candle chart ─────────────────────────────────────
    chart_left   = cx0 + int(S * 0.06)
    chart_right  = cx1 - int(S * 0.06)
    chart_top    = cy0 + int(S * 0.10)
    chart_bottom = cy1 - int(S * 0.08)
    chart_w      = chart_right - chart_left
    chart_h      = chart_bottom - chart_top

    # Candle data: (wick_top_ratio, wick_bottom_ratio, open_ratio, close_ratio, is_up)
    # Using Chinese convention: red = up
    candles = [
        (0.05, 0.60, 0.10, 0.45,  True),    # small red
        (0.12, 0.72, 0.18, 0.60,  True),    # medium red
        (0.28, 0.82, 0.72, 0.45,  False),   # green
        (0.20, 0.85, 0.28, 0.72,  True),    # red
        (0.35, 0.90, 0.40, 0.78,  True),    # big red
        (0.48, 0.96, 0.55, 0.88,  True),    # biggest red
    ]
    n = len(candles)
    gap = chart_w // (n * 2 + 1)
    cw = gap

    candle_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cl_draw = ImageDraw.Draw(candle_layer)

    for i, (pc_low, pc_high, pc_open, pc_close, is_up) in enumerate(candles):
        x = chart_left + gap + i * 2 * gap + gap // 2
        wick_top    = chart_top + int(pc_low * chart_h)
        wick_bottom = chart_top + int(pc_high * chart_h)
        open_y      = chart_top + int(pc_open * chart_h)
        close_y     = chart_top + int(pc_close * chart_h)

        color = CANDLE_UP if is_up else CANDLE_DOWN

        body_top = min(open_y, close_y)
        body_bottom = max(open_y, close_y)

        draw_candle(cl_draw, x, body_top, body_bottom,
                    wick_top, wick_bottom, color, w=cw)

    # Apply card mask
    candle_layer.putalpha(card_mask)
    img = Image.alpha_composite(img, candle_layer)
    draw = ImageDraw.Draw(img)

    # ── 5. Lightweight trend line (minimal, floats above) ──
    pts = [
        (chart_left + gap, chart_top + int(0.72 * chart_h)),
        (chart_left + gap * 3, chart_top + int(0.62 * chart_h)),
        (chart_left + gap * 5, chart_top + int(0.40 * chart_h)),
        (chart_left + gap * 7, chart_top + int(0.30 * chart_h)),
        (chart_right - gap, chart_top + int(0.22 * chart_h)),
    ]

    # Thin glow line
    for j in range(len(pts) - 1):
        draw.line([pts[j], pts[j + 1]], fill=(255, 255, 255, 160), width=5)
        draw.line([pts[j], pts[j + 1]], fill=(255, 255, 255, 50), width=9)

    # Small dot at each point
    for px, py in pts:
        draw.ellipse([px - 5, py - 5, px + 5, py + 5],
                     fill=(255, 255, 255, 220))

    # Arrow tip at last point
    lx, ly = pts[-1]
    ppx, ppy = pts[-2]
    dx = lx - ppx
    dy = ly - ppy
    leng = math.sqrt(dx * dx + dy * dy)
    ux, uy = dx / leng, dy / leng
    hs = int(S * 0.020)
    draw.polygon([
        (lx + 2, ly - 2),
        (lx - int(hs * ux + hs * 0.4 * uy) + 2,
         ly - int(hs * uy - hs * 0.4 * ux) - 2),
        (lx - int(hs * ux - hs * 0.4 * uy) + 2,
         ly - int(hs * uy + hs * 0.4 * ux) - 2),
    ], fill=(255, 255, 255, 220))

    # ── 6. Text: brand name ─────────────────────────────────
    fnt = _font(["/System/Library/Fonts/SFProText-Bold.otf",
                 "/System/Library/Fonts/Helvetica.ttc"], int(S * 0.075))

    name = "go-stock"
    bb = draw.textbbox((0, 0), name, font=fnt)
    tw = bb[2] - bb[0]
    tx = (S - tw) // 2
    ty = int(S * 0.80)

    # Text shadow
    draw.text((tx + 1, ty + 1), name, fill=(10, 20, 40, 120), font=fnt)
    # Main white text
    draw.text((tx, ty), name, fill=WHITE, font=fnt)
    # Blue highlight on first "g"
    draw.text((tx, ty), "g", fill=BRAND_LIGHT, font=fnt)

    # ── 7. Tagline ──────────────────────────────────────────
    sfnt = _font(["/System/Library/Fonts/SFProText-Regular.otf",
                  "/System/Library/Fonts/Helvetica.ttc"], int(S * 0.026))
    tag = "AI 智能选股 · 实时行情"
    tb = draw.textbbox((0, 0), tag, font=sfnt)
    stw = tb[2] - tb[0]
    stx = (S - stw) // 2
    sty = int(S * 0.89)
    draw.text((stx, sty), tag, fill=(160, 200, 240, 160), font=sfnt)

    # ── 8. Final: rounded corners mask ────────────────────
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=180, fill=255)
    img.putalpha(mask)

    return img


# ── output ───────────────────────────────────────────────────

def resize_and_save(src, sz, path):
    src.resize((sz, sz), Image.LANCZOS).save(path, "PNG")
    print(f"  {sz:4d}px → {os.path.basename(path)}")


def main():
    print("=" * 60)
    print("  go-stock App Icon Generator — v3")
    print("  Chinese market colors: red = 涨, green = 跌")
    print("=" * 60)

    print("\nGenerating 1024×1024 master icon...")
    icon = create_icon()

    master = os.path.join(OUTPUT_DIR, "Icon-App-1024x1024@1x.png")
    icon.save(master, "PNG")
    print(f"  Master saved: {master}")

    sizes = [
        (20, "Icon-App-20x20@1x.png"),
        (20, "Icon-App-20x20@2x.png"),
        (20, "Icon-App-20x20@3x.png"),
        (29, "Icon-App-29x29@1x.png"),
        (29, "Icon-App-29x29@2x.png"),
        (29, "Icon-App-29x29@3x.png"),
        (40, "Icon-App-40x40@1x.png"),
        (40, "Icon-App-40x40@2x.png"),
        (40, "Icon-App-40x40@3x.png"),
        (60, "Icon-App-60x60@2x.png"),
        (60, "Icon-App-60x60@3x.png"),
        (76, "Icon-App-76x76@1x.png"),
        (76, "Icon-App-76x76@2x.png"),
        (83, "Icon-App-83.5x83.5@2x.png"),
    ]

    print(f"\nGenerating {len(sizes)} icon sizes:")
    for sz, fname in sizes:
        resize_and_save(icon, sz, os.path.join(OUTPUT_DIR, fname))

    print(f"\n{'=' * 60}")
    print(f"  Done! All icons → {OUTPUT_DIR}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
