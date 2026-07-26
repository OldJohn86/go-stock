#!/usr/bin/env python3
"""
go-stock App Icon Generator — v4 (金铲子黄金主题)
Design: Golden shovel digging into stock chart on deep navy canvas.
Chinese market colors: red=up (涨), green=down (跌).
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

OUTPUT_DIR = "/Users/jonathanchen/gitee/github/go-stock/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
BASE_SIZE = 1024

# ── brand colors ─────────────────────────────────
BRAND_BLUE    = (25, 118, 210)    # #1976D2
BRAND_DARK    = (8, 18, 40)       # deep navy
BRAND_LIGHT   = (66, 165, 245)    # light blue accent

# Golden shovel colors
GOLD_LIGHT    = (255, 215, 0)     # #FFD700
GOLD_MID      = (255, 193, 7)     # #FFC107
GOLD_DARK     = (255, 160, 0)     # #FFA000
GOLD_SHADOW   = (180, 120, 0)     # deep gold shadow
GOLD_HIGHLIGHT= (255, 235, 120)   # bright gold highlight

# Market candle colors
CANDLE_UP     = (244, 67, 54)     # red = 涨
CANDLE_DOWN   = (0, 200, 83)      # green = 跌
WHITE         = (255, 255, 255)
SOFT_WHITE    = (200, 215, 235)

# ── helpers ─────────────────────────────────────────

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
    """Radial glow via concentric ellipses."""
    g = Image.new("RGBA", (base.width, base.height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for s in range(steps, 0, -2):
        a = int(180 * math.exp(-((s / steps) ** 2) * 3))
        gd.ellipse(
            [cx - s * r // steps, cy - s * r // steps,
             cx + s * r // steps, cy + s * r // steps],
            fill=(color[0], color[1], color[2], min(a, color[3])))
    return Image.alpha_composite(base, g)


def draw_candle(draw, cx, body_top, body_bottom, wick_top, wick_bottom, color, w=10):
    """Draw a single candlestick."""
    # Wick
    draw.line([(cx, wick_top), (cx, wick_bottom)], fill=color, width=3)
    # Body
    body_h = max(body_bottom - body_top, 4)
    draw.rounded_rectangle(
        [cx - w // 2, body_top, cx + w // 2, body_bottom],
        radius=3, fill=color
    )
    # Highlight
    hl = (min(color[0] + 50, 255), min(color[1] + 50, 255), min(color[2] + 50, 255))
    draw.rounded_rectangle(
        [cx - w // 2 + 2, body_top + 2, cx + w // 2 - 2, body_top + body_h // 3],
        radius=2, fill=hl
    )


def draw_shovel(draw, cx, cy, size, angle_deg=-30):
    """
    Draw a stylized golden shovel centered at (cx, cy).
    Handle goes up-right, blade is at the bottom-left of the center.
    angle_deg: rotation of the whole shovel.
    size: relative scale (fraction of BASE_SIZE).
    """
    S = BASE_SIZE
    s = size * S

    # Shovel proportions
    handle_len = s * 0.65
    handle_w   = s * 0.035
    grip_r     = s * 0.035
    blade_w    = s * 0.30
    blade_h    = s * 0.20
    neck_len   = s * 0.06

    # We draw along the Y-axis (handle up, blade down) then rotate
    # Handle: from top (grip) to neck
    handle_top    = -handle_len
    handle_bottom = neck_len

    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cd = ImageDraw.Draw(canvas)

    # ── Handle (shaft) ──
    # Thick golden shaft with a subtle gradient
    for i in range(3):
        offset = i - 1  # -1, 0, 1
        lw = handle_w + 2 * abs(offset)
        alpha = 180 if offset == 0 else 120 if abs(offset) == 1 else 60
        # Slight color variation toward edges
        col = GOLD_MID if offset == 0 else GOLD_DARK
        cd.line([(offset * 1.5, handle_top), (offset * 1.5, handle_bottom)],
                fill=(col[0], col[1], col[2], alpha), width=int(lw))

    # Main handle highlight (bright stripe)
    cd.line([(-1, handle_top), (-1, handle_bottom)],
            fill=(*GOLD_HIGHLIGHT, 100), width=int(handle_w * 0.3))

    # ── Grip (rounded top) ──
    grip_y = handle_top
    cd.rounded_rectangle(
        [-grip_r * 1.5, grip_y - grip_r * 2, grip_r * 1.5, grip_y + grip_r * 0.5],
        radius=int(grip_r * 0.8),
        fill=(*GOLD_MID, 220)
    )
    # Grip highlight
    cd.rounded_rectangle(
        [-grip_r * 1.2, grip_y - grip_r * 1.8, -grip_r * 0.3, grip_y - grip_r * 0.5],
        radius=int(grip_r * 0.4),
        fill=(*GOLD_HIGHLIGHT, 150)
    )

    # ── Blade (shovel head) ──
    # Blade starts from neck, widens downward, curves at the bottom
    blade_top = neck_len

    # Gold gradient fill for blade
    blade_pts = [
        (-blade_w * 0.15, blade_top),             # top left of blade
        (blade_w * 0.15, blade_top),              # top right of blade
        (blade_w * 0.50, blade_top + blade_h * 0.6),  # right mid
        (blade_w * 0.48, blade_top + blade_h * 0.85), # right lower
        (blade_w * 0.20, blade_top + blade_h),       # bottom right curve
        (0, blade_top + blade_h * 1.02),             # bottom center point
        (-blade_w * 0.20, blade_top + blade_h),      # bottom left curve
        (-blade_w * 0.48, blade_top + blade_h * 0.85),# left lower
        (-blade_w * 0.50, blade_top + blade_h * 0.6), # left mid
    ]

    # Draw blade shadow (offset slightly)
    shadow_pts = [(x + 2, y + 2) for x, y in blade_pts]
    cd.polygon(shadow_pts, fill=(*GOLD_SHADOW, 100))

    # Draw blade with gold gradient
    cd.polygon(blade_pts, fill=(*GOLD_MID, 230))

    # Blade edge highlight (top of blade where it meets the neck)
    cd.line([
        (-blade_w * 0.15, blade_top + 2),
        (blade_w * 0.15, blade_top + 2)
    ], fill=(*GOLD_HIGHLIGHT, 180), width=3)

    # Blade contour line
    cd.line(blade_pts + [blade_pts[0]], fill=(*GOLD_DARK, 160), width=2)

    # Blade center ridge
    cd.line([
        (0, blade_top + blade_h * 0.1),
        (0, blade_top + blade_h * 0.85)
    ], fill=(*GOLD_HIGHLIGHT, 80), width=int(blade_w * 0.06))

    # Rotate
    rotated = canvas.rotate(angle_deg, center=(0, 0), expand=False,
                            fillcolor=(0, 0, 0, 0))

    # Composite onto main image at desired position
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(rotated, (cx, cy), rotated)
    return out


def draw_gold_coins(draw, center_x, y_positions, sizes, alpha=100):
    """Draw small golden coins scattered around."""
    for y, r in zip(y_positions, sizes):
        # Coin glow
        for s in range(5, 0, -1):
            a = int(alpha * math.exp(-((5 - s) ** 2) * 0.3))
            draw.ellipse(
                [center_x - r - s * 2, y - r - s * 2,
                 center_x + r + s * 2, y + r + s * 2],
                fill=(*GOLD_MID, a // 3)
            )
        # Coin face
        draw.ellipse(
            [center_x - r, y - r, center_x + r, y + r],
            fill=(*GOLD_MID, alpha)
        )
        # Coin rim
        draw.ellipse(
            [center_x - r, y - r, center_x + r, y + r],
            outline=(*GOLD_LIGHT, alpha + 50), width=2
        )
        # Inner circle
        draw.ellipse(
            [center_x - r * 0.6, y - r * 0.6, center_x + r * 0.6, y + r * 0.6],
            outline=(*GOLD_LIGHT, alpha), width=1
        )
        # "¥" or center dot
        draw.ellipse(
            [center_x - r * 0.15, y - r * 0.15, center_x + r * 0.15, y + r * 0.15],
            fill=(*GOLD_HIGHLIGHT, alpha + 50)
        )


# ── main icon ──────────────────────────────────────

def create_icon():
    S = BASE_SIZE
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # ── 1. Deep navy gradient background ──
    bg = ver_gradient(S, S, [
        (6, 14, 32),         # very dark navy top
        (8, 22, 52),         # dark navy
        (12, 35, 78),        # mid navy
        (20, 50, 100),       # slightly lighter bottom
    ])
    img.paste(bg, (0, 0))

    # ── 2. Golden ambient glow (center) ──
    img = glow_bloom(img, S // 2, S // 2, int(S * 0.40),
                     (255, 200, 50, 18), 40)

    # ── 3. Subtle market chart in background (faint) ──
    chart_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ch_draw = ImageDraw.Draw(chart_layer)

    chart_left   = int(S * 0.12)
    chart_right  = int(S * 0.88)
    chart_top    = int(S * 0.20)
    chart_bottom = int(S * 0.75)
    chart_w      = chart_right - chart_left
    chart_h      = chart_bottom - chart_top

    # Draw faint background candles
    bg_candles = [
        (0.10, 0.65, 0.22, 0.48, True),
        (0.18, 0.75, 0.28, 0.58, True),
        (0.30, 0.80, 0.65, 0.50, False),
        (0.35, 0.82, 0.40, 0.68, True),
        (0.45, 0.88, 0.52, 0.76, True),
        (0.50, 0.92, 0.62, 0.82, True),
        (0.55, 0.72, 0.58, 0.65, True),
        (0.60, 0.78, 0.68, 0.70, False),
        (0.68, 0.90, 0.72, 0.85, True),
    ]
    n = len(bg_candles)
    gap = chart_w // (n * 2 + 1)
    cw = max(gap - 2, 6)

    for i, (pc_low, pc_high, pc_open, pc_close, is_up) in enumerate(bg_candles):
        x = chart_left + gap + i * 2 * gap + gap // 2
        wick_top    = chart_top + int(pc_low * chart_h)
        wick_bottom = chart_top + int(pc_high * chart_h)
        open_y      = chart_top + int(pc_open * chart_h)
        close_y     = chart_top + int(pc_close * chart_h)
        color = CANDLE_UP if is_up else CANDLE_DOWN
        body_top = min(open_y, close_y)
        body_bottom = max(open_y, close_y)

        # Wick
        ch_draw.line([(x, wick_top), (x, wick_bottom)], fill=(*color, 40), width=2)
        body_h = max(body_bottom - body_top, 3)
        ch_draw.rounded_rectangle(
            [x - cw // 2, body_top, x + cw // 2, body_bottom],
            radius=2, fill=(*color, 35)
        )

    # Faint trend line going up
    trend_pts = [
        (chart_left + gap, chart_top + int(0.78 * chart_h)),
        (chart_left + gap * 3, chart_top + int(0.70 * chart_h)),
        (chart_left + gap * 5, chart_top + int(0.52 * chart_h)),
        (chart_left + gap * 7, chart_top + int(0.40 * chart_h)),
        (chart_right - gap, chart_top + int(0.28 * chart_h)),
    ]
    for j in range(len(trend_pts) - 1):
        ch_draw.line([trend_pts[j], trend_pts[j + 1]],
                     fill=(*SOFT_WHITE, 40), width=3)
        ch_draw.line([trend_pts[j], trend_pts[j + 1]],
                     fill=(*BRAND_LIGHT, 30), width=6)

    img = Image.alpha_composite(img, chart_layer)

    # ── 4. Golden shovel (main element) ──
    # Position shovel at center-right, tilted
    shovel = draw_shovel(
        draw=None,
        cx=S // 2 + int(S * 0.04),
        cy=S // 2 + int(S * 0.02),
        size=0.55,
        angle_deg=-25
    )
    img = Image.alpha_composite(img, shovel)

    # ── 5. Gold coins / sparkles near the shovel blade ──
    coin_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    co_draw = ImageDraw.Draw(coin_layer)

    # Scattered coins near where the shovel digs
    coin_positions = [
        (S // 2 - int(S * 0.30), S // 2 + int(S * 0.22), 18),
        (S // 2 - int(S * 0.22), S // 2 + int(S * 0.32), 14),
        (S // 2 - int(S * 0.38), S // 2 + int(S * 0.30), 12),
        (S // 2 - int(S * 0.15), S // 2 + int(S * 0.20), 10),
    ]
    for cx, cy, r in coin_positions:
        # Outer glow
        for s in range(6, 0, -1):
            a = int(60 * math.exp(-((6 - s) ** 2) * 0.4))
            co_draw.ellipse(
                [cx - r - s * 2, cy - r - s * 2,
                 cx + r + s * 2, cy + r + s * 2],
                fill=(*GOLD_MID, a)
            )
        co_draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*GOLD_MID, 180)
        )
        co_draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            outline=(*GOLD_LIGHT, 220), width=2
        )

    # Sparkles (十字光斑)
    sparkle_positions = [
        (S // 2 + int(S * 0.20), S // 2 - int(S * 0.15), 12),
        (S // 2 + int(S * 0.08), S // 2 - int(S * 0.05), 8),
        (S // 2 - int(S * 0.30), S // 2 - int(S * 0.20), 6),
    ]
    for spx, spy, sl in sparkle_positions:
        co_draw.line(
            [(spx - sl, spy), (spx + sl, spy)],
            fill=(*GOLD_LIGHT, 200), width=2
        )
        co_draw.line(
            [(spx, spy - sl), (spx, spy + sl)],
            fill=(*GOLD_LIGHT, 200), width=2
        )
        # Center dot
        co_draw.ellipse(
            [spx - 2, spy - 2, spx + 2, spy + 2],
            fill=(255, 255, 255, 220)
        )

    img = Image.alpha_composite(img, coin_layer)

    draw = ImageDraw.Draw(img)

    # ── 6. Text: brand name ──
    fnt = _font(["/System/Library/Fonts/SFProText-Bold.otf",
                 "/System/Library/Fonts/Helvetica.ttc"], int(S * 0.070))

    name = "go-stock"
    bb = draw.textbbox((0, 0), name, font=fnt)
    tw = bb[2] - bb[0]
    tx = (S - tw) // 2
    ty = int(S * 0.82)

    # Gold text shadow
    draw.text((tx + 1, ty + 1), name, fill=(*GOLD_DARK, 140), font=fnt)
    # White main text
    draw.text((tx, ty), name, fill=WHITE, font=fnt)
    # Gold highlight on "go-"
    gow = draw.textbbox((0, 0), "go-", font=fnt)
    gtw = gow[2] - gow[0]
    draw.text((tx, ty), "go-", fill=(*GOLD_LIGHT, 230), font=fnt)

    # ── 7. Tagline ──
    sfnt = _font(["/System/Library/Fonts/SFProText-Regular.otf",
                  "/System/Library/Fonts/Helvetica.ttc"], int(S * 0.024))
    tag = "AI 智能选股 · 实时行情"
    tb = draw.textbbox((0, 0), tag, font=sfnt)
    stw = tb[2] - tb[0]
    stx = (S - stw) // 2
    sty = int(S * 0.90)
    draw.text((stx, sty), tag, fill=(160, 190, 220, 160), font=sfnt)

    # ── 8. Rounded corners mask ──
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=180, fill=255)
    img.putalpha(mask)

    return img


# ── output ─────────────────────────────────────────

def resize_and_save(src, sz, path):
    src.resize((sz, sz), Image.LANCZOS).save(path, "PNG")
    print(f"  {sz:4d}px → {os.path.basename(path)}")


def main():
    print("=" * 60)
    print("  go-stock App Icon Generator — v4")
    print("  金铲子主题 · Chinese market colors")
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
