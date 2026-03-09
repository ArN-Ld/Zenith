#!/usr/bin/env python3
"""
Generate Zenith app icon — North star / Polaris style.
Deep space background + bright 4-ray star with soft blue glow.
"""

import math
import subprocess
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
CENTER = SIZE // 2

# ─── Colors ──────────────────────────────────────────────
BG_INNER = (10, 12, 28)     # Very dark navy center
BG_OUTER = (5, 6, 15)       # Near-black edge

STAR_WHITE = (245, 248, 255, 255)   # Star core — blue-white
GLOW_BLUE  = (80, 140, 255, 90)     # Soft blue glow
GLOW_OUTER = (40, 80, 200, 30)      # Wide diffuse glow
SPECKLE    = (200, 210, 255, 60)    # Background star speckles


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_background(img):
    """Deep space background: dark navy with subtle radial gradient."""
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        c = lerp_color(BG_INNER, BG_OUTER, t)
        draw.line([(0, y), (SIZE, y)], fill=c)

    # Soft radial highlight behind star
    cx, cy = CENTER, int(SIZE * 0.44)
    highlight = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    for r in range(350, 0, -1):
        a = int(18 * (1 - r / 350))
        hd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 100, 200, a))
    img.paste(Image.alpha_composite(img.convert('RGBA'), highlight))


def draw_speckles(img):
    """A handful of tiny background stars."""
    import random
    random.seed(7)
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(28):
        x = random.randint(80, SIZE - 80)
        y = random.randint(60, SIZE - 60)
        r = random.uniform(1.2, 2.8)
        a = random.randint(25, 75)
        od.ellipse([x - r, y - r, x + r, y + r], fill=(220, 230, 255, a))
    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))


def draw_star(img):
    """4-pointed north-star / Polaris: two long vertical rays, two shorter horizontal."""
    cx, cy = CENTER, int(SIZE * 0.44)

    long_len  = int(SIZE * 0.345)   # half-length of vertical rays
    short_len = int(SIZE * 0.195)   # half-length of horizontal rays
    waist     = int(SIZE * 0.028)   # waist width between ray bases

    def star_poly(long_l, short_l, w):
        """Compute the 8 points of the 4-pointed star polygon."""
        return [
            (cx,          cy - long_l),   # top
            (cx + w,      cy - w),
            (cx + short_l, cy),           # right
            (cx + w,      cy + w),
            (cx,          cy + long_l),   # bottom
            (cx - w,      cy + w),
            (cx - short_l, cy),           # left
            (cx - w,      cy - w),
        ]

    # ── Glow layers (wide blurred) ──
    for (glow_r, gl_l, gs_l, ga) in [
        (60,  long_len + 80, short_len + 50, 18),
        (30,  long_len + 40, short_len + 25, 30),
        (16,  long_len + 15, short_len + 10, 50),
    ]:
        glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.polygon(star_poly(gl_l, gs_l, waist + 14), fill=(*GLOW_BLUE[:3], ga))
        glow = glow.filter(ImageFilter.GaussianBlur(glow_r))
        img.paste(Image.alpha_composite(img.convert('RGBA'), glow))

    # ── Tight inner glow ──
    inner = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    id_ = ImageDraw.Draw(inner)
    id_.polygon(star_poly(long_len + 6, short_len + 4, waist + 6), fill=(*GLOW_BLUE[:3], 80))
    inner = inner.filter(ImageFilter.GaussianBlur(10))
    img.paste(Image.alpha_composite(img.convert('RGBA'), inner))

    # ── Star body ──
    main = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    md = ImageDraw.Draw(main)
    pts = star_poly(long_len, short_len, waist)
    md.polygon(pts, fill=STAR_WHITE)

    # Subtle centre brightness boost
    for r in range(int(SIZE * 0.07), 0, -1):
        a = int(12 * (1 - r / (SIZE * 0.07)))
        md.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, a))

    img.paste(Image.alpha_composite(img.convert('RGBA'), main))


def apply_squircle_mask(img):
    """macOS continuous-corner (squircle) mask, ~22% radius."""
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1],
        radius=int(SIZE * 0.2237), fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(1))
    result = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def generate_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    print("  Drawing background...")
    draw_background(img)
    print("  Drawing speckles...")
    draw_speckles(img)
    print("  Drawing star...")
    draw_star(img)
    print("  Applying squircle mask...")
    return apply_squircle_mask(img)


def export_sizes(master, out_dir):
    sizes = [
        ("icon_16x16.png",     16),
        ("icon_16x16@2x.png",  32),
        ("icon_32x32.png",     32),
        ("icon_32x32@2x.png",  64),
        ("icon_64x64.png",     64),
        ("icon_128x128.png",   128),
        ("icon_128x128@2x.png",256),
        ("icon_256x256.png",   256),
        ("icon_256x256@2x.png",512),
        ("icon_512x512.png",   512),
        ("icon_512x512@2x.png",1024),
    ]
    for filename, px in sizes:
        resized = master.resize((px, px), Image.LANCZOS)
        (out_dir / filename).write_bytes(b"")  # ensure path exists
        resized.save(str(out_dir / filename), 'PNG')
        print(f"  ✓ {filename} ({px}×{px})")


def create_icns(icon_dir, icns_path):
    import shutil
    iconset = icon_dir.parent / "Zenith.iconset"
    iconset.mkdir(exist_ok=True)
    names = [
        "icon_16x16.png", "icon_16x16@2x.png",
        "icon_32x32.png",  "icon_32x32@2x.png",
        "icon_128x128.png","icon_128x128@2x.png",
        "icon_256x256.png","icon_256x256@2x.png",
        "icon_512x512.png","icon_512x512@2x.png",
    ]
    for name in names:
        src = icon_dir / name
        if src.exists():
            shutil.copy2(str(src), str(iconset / name))
    result = subprocess.run(
        ["iconutil", "--convert", "icns", "--output", str(icns_path), str(iconset)],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"  ✓ {icns_path.name}")
    else:
        print(f"  ✗ iconutil: {result.stderr}")
    shutil.rmtree(str(iconset), ignore_errors=True)


def main():
    script_dir = Path(__file__).parent.parent   # scripts/ → repo root
    icon_dir = script_dir / "Sources" / "Zenith" / "Assets.xcassets" / "AppIcon.appiconset"
    icns_path = script_dir / "Resources" / "Zenith.icns"

    print("==> Generating Zenith icon (north-star design)")
    master = generate_icon()

    master_path = icon_dir / "icon_master_1024.png"
    master.save(str(master_path), 'PNG')
    print(f"  ✓ Master: {master_path.name}")

    print("==> Exporting sizes...")
    export_sizes(master, icon_dir)

    print("==> Creating .icns...")
    create_icns(icon_dir, icns_path)
    print("==> Done!")


if __name__ == "__main__":
    main()



def draw_rounded_rect_bg(img):
    """Draw macOS-style dark gradient background with subtle radial light."""
    draw = ImageDraw.Draw(img, 'RGBA')

    # Vertical gradient
    for y in range(SIZE):
        t = y / SIZE
        if t < 0.4:
            c = lerp_color(BG_TOP, BG_MID, t / 0.4)
        else:
            c = lerp_color(BG_MID, BG_BOT, (t - 0.4) / 0.6)
        draw.line([(0, y), (SIZE, y)], fill=c)

    # Subtle radial highlight (upper center)
    highlight = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    cx, cy = CENTER, int(SIZE * 0.35)
    for r in range(300, 0, -1):
        alpha = int(25 * (1 - r / 300))
        hd.ellipse([cx - r, cy - r, cx + r, cy + r],
                    fill=(100, 60, 200, alpha))
    img.paste(Image.alpha_composite(img.convert('RGBA'), highlight))

    # Subtle grid/noise texture via fine dots
    import random
    random.seed(42)
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(800):
        x = random.randint(0, SIZE - 1)
        y = random.randint(0, SIZE - 1)
        a = random.randint(3, 12)
        od.point((x, y), fill=(255, 255, 255, a))
    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))


def draw_shield(img):
    """Draw a modern shield shape with gradient fill and glow border."""
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    cx, cy = CENTER, int(SIZE * 0.48)
    w = int(SIZE * 0.30)   # half-width
    h_top = int(SIZE * 0.22)   # height above center
    h_bot = int(SIZE * 0.28)   # height below center (pointed)

    # Shield path points (simplified bezier via polygon)
    pts = []
    steps = 60

    # Top-left arc
    for i in range(steps + 1):
        t = i / steps
        # Flat top with rounded shoulders
        x = cx - w + t * 2 * w
        # Parabolic top curve (slight dome)
        y_off = -h_top + (t - 0.5) ** 2 * h_top * 0.3
        y = cy + y_off
        pts.append((x, y))

    # Right side going down to point
    for i in range(1, steps + 1):
        t = i / steps
        x = cx + w * (1 - t * 0.95)
        y = cy + h_bot * t ** 0.7
        pts.append((x, y))

    # Bottom point
    pts.append((cx, cy + h_bot + int(SIZE * 0.04)))

    # Left side going up
    for i in range(1, steps):
        t = i / steps
        x = cx - w * (1 - (1 - t) * 0.95)
        y = cy + h_bot * (1 - t) ** 0.7
        pts.append((x, y))

    # Glow layer (blurred shield outline)
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for thickness in range(18, 0, -1):
        alpha = int(40 * (1 - thickness / 18))
        color = (*SHIELD_OUTER, alpha)
        # Draw with offset for thickness
        gd.polygon(pts, outline=color)
    glow = glow.filter(ImageFilter.GaussianBlur(12))
    img.paste(Image.alpha_composite(img.convert('RGBA'), glow))

    # Shield fill with gradient
    shield_mask = Image.new('L', (SIZE, SIZE), 0)
    md = ImageDraw.Draw(shield_mask)
    md.polygon(pts, fill=255)

    shield_fill = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shield_fill)
    top_y = cy - h_top
    bot_y = cy + h_bot + int(SIZE * 0.04)
    for y in range(top_y, bot_y):
        t = (y - top_y) / (bot_y - top_y)
        c = lerp_color(SHIELD_FILL_TOP, SHIELD_FILL_BOT, t)
        sd.line([(0, y), (SIZE, y)], fill=(*c, 220))

    # Apply mask
    shield_fill.putalpha(shield_mask)
    img.paste(Image.alpha_composite(img.convert('RGBA'), shield_fill))

    # Shield border (crisp)
    draw_on = ImageDraw.Draw(img.convert('RGBA') if img.mode != 'RGBA' else img)
    draw_on.polygon(pts, outline=(*SHIELD_OUTER, 160))

    # Inner subtle border
    inner_pts = []
    for (x, y) in pts:
        dx = x - cx
        dy = y - cy
        dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0:
            factor = max(0, dist - 3) / dist
            inner_pts.append((cx + dx * factor, cy + dy * factor))
        else:
            inner_pts.append((x, y))
    draw_on.polygon(inner_pts, outline=(120, 80, 255, 60))

    return pts, cx, cy, w, h_top, h_bot


def draw_speed_arc(img, cx, cy):
    """Draw a speedometer arc inside the shield with gradient and ticks."""
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    arc_cx = cx
    arc_cy = cy + int(SIZE * 0.02)
    arc_r = int(SIZE * 0.17)

    start_angle = 210  # degrees (left)
    end_angle = 330    # degrees (right)
    arc_width = int(SIZE * 0.025)

    # Draw gradient arc (cyan → green → purple)
    for i in range(200):
        t = i / 199
        angle = math.radians(start_angle + t * (end_angle - start_angle))

        if t < 0.4:
            color = lerp_color(ARC_CYAN, ARC_GREEN, t / 0.4)
        elif t < 0.7:
            color = lerp_color(ARC_GREEN, ARC_PURPLE, (t - 0.4) / 0.3)
        else:
            color = lerp_color(ARC_PURPLE, ARC_CYAN, (t - 0.7) / 0.3)

        x1 = arc_cx + math.cos(angle) * arc_r
        y1 = arc_cy - math.sin(angle) * arc_r

        # Draw thick point
        half = arc_width // 2
        draw.ellipse([x1 - half, y1 - half, x1 + half, y1 + half],
                     fill=(*color, 230))

    # Glow behind arc
    arc_glow = overlay.filter(ImageFilter.GaussianBlur(8))
    enhancer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    for x in range(SIZE):
        for y_px in range(SIZE):
            r, g, b, a = arc_glow.getpixel((x, y_px))
            if a > 5:
                enhancer.putpixel((x, y_px), (r, g, b, min(255, a)))
    # Too slow pixel-by-pixel, use composite instead
    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))

    # Tick marks
    tick_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    td = ImageDraw.Draw(tick_overlay)
    num_ticks = 12
    for i in range(num_ticks + 1):
        t = i / num_ticks
        angle = math.radians(start_angle + t * (end_angle - start_angle))
        is_major = (i % 3 == 0)

        r_inner = arc_r - (int(SIZE * 0.04) if is_major else int(SIZE * 0.025))
        r_outer = arc_r + (int(SIZE * 0.03) if is_major else int(SIZE * 0.018))

        x1 = arc_cx + math.cos(angle) * r_inner
        y1 = arc_cy - math.sin(angle) * r_inner
        x2 = arc_cx + math.cos(angle) * r_outer
        y2 = arc_cy - math.sin(angle) * r_outer

        width = 3 if is_major else 1
        alpha = 200 if is_major else 120
        td.line([(x1, y1), (x2, y2)], fill=(200, 200, 240, alpha), width=width)

    img.paste(Image.alpha_composite(img.convert('RGBA'), tick_overlay))

    # Needle (pointing to ~75% position = fast)
    needle_t = 0.78
    needle_angle = math.radians(start_angle + needle_t * (end_angle - start_angle))
    needle_len = arc_r - int(SIZE * 0.02)

    nx = arc_cx + math.cos(needle_angle) * needle_len
    ny = arc_cy - math.sin(needle_angle) * needle_len

    needle_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    nd = ImageDraw.Draw(needle_overlay)

    # Needle body (tapered)
    perp_angle = needle_angle + math.pi / 2
    base_w = int(SIZE * 0.008)
    tip_w = 1

    bx1 = arc_cx + math.cos(perp_angle) * base_w
    by1 = arc_cy - math.sin(perp_angle) * base_w
    bx2 = arc_cx - math.cos(perp_angle) * base_w
    by2 = arc_cy + math.sin(perp_angle) * base_w

    nd.polygon([(bx1, by1), (nx, ny), (bx2, by2)],
               fill=(*NEEDLE_COLOR, 240))

    # Needle center dot
    dot_r = int(SIZE * 0.015)
    nd.ellipse([arc_cx - dot_r, arc_cy - dot_r, arc_cx + dot_r, arc_cy + dot_r],
               fill=(255, 255, 255, 240))
    dot_r2 = int(SIZE * 0.008)
    nd.ellipse([arc_cx - dot_r2, arc_cy - dot_r2, arc_cx + dot_r2, arc_cy + dot_r2],
               fill=(*NEEDLE_COLOR, 255))

    # Needle glow
    needle_glow = needle_overlay.filter(ImageFilter.GaussianBlur(4))
    img.paste(Image.alpha_composite(img.convert('RGBA'), needle_glow))
    img.paste(Image.alpha_composite(img.convert('RGBA'), needle_overlay))

    return arc_cx, arc_cy


def draw_lock_icon(img, cx, cy):
    """Draw a small lock/VPN symbol above the arc."""
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    lock_cx = cx
    lock_cy = cy - int(SIZE * 0.12)  # Above the arc

    # Lock body
    bw = int(SIZE * 0.045)
    bh = int(SIZE * 0.04)
    r = int(SIZE * 0.006)
    draw.rounded_rectangle(
        [lock_cx - bw, lock_cy, lock_cx + bw, lock_cy + bh],
        radius=r, fill=(0, 220, 255, 200)
    )

    # Lock shackle (arc above body)
    shackle_r = int(SIZE * 0.032)
    shackle_w = int(SIZE * 0.008)
    for angle_deg in range(0, 181, 2):
        angle = math.radians(angle_deg)
        x = lock_cx + math.cos(angle) * shackle_r
        y = lock_cy - math.sin(angle) * shackle_r
        draw.ellipse([x - shackle_w, y - shackle_w, x + shackle_w, y + shackle_w],
                     fill=(0, 220, 255, 200))

    # Keyhole (small dark circle + triangle)
    kh_r = int(SIZE * 0.01)
    draw.ellipse([lock_cx - kh_r, lock_cy + bh // 3 - kh_r,
                  lock_cx + kh_r, lock_cy + bh // 3 + kh_r],
                 fill=(15, 10, 50, 255))

    # Lock glow
    lock_glow = overlay.filter(ImageFilter.GaussianBlur(6))
    img.paste(Image.alpha_composite(img.convert('RGBA'), lock_glow))
    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))


def draw_connection_dots(img, cx, cy):
    """Draw subtle connection/network dots around the shield for depth."""
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    import random
    random.seed(99)

    for _ in range(40):
        angle = random.uniform(0, 2 * math.pi)
        dist = random.uniform(SIZE * 0.34, SIZE * 0.43)
        x = cx + math.cos(angle) * dist
        y = cy + math.sin(angle) * dist

        # Only draw if within image bounds with padding
        if PAD < x < SIZE - PAD and PAD < y < SIZE - PAD:
            r = random.uniform(1.5, 3.5)
            alpha = random.randint(20, 70)
            color_choice = random.choice([ARC_CYAN, ARC_GREEN, ARC_PURPLE])
            draw.ellipse([x - r, y - r, x + r, y + r],
                         fill=(*color_choice, alpha))

    # Some connecting lines between nearby dots
    dots = []
    random.seed(99)
    for _ in range(40):
        angle = random.uniform(0, 2 * math.pi)
        dist = random.uniform(SIZE * 0.34, SIZE * 0.43)
        x = cx + math.cos(angle) * dist
        y = cy + math.sin(angle) * dist
        if PAD < x < SIZE - PAD and PAD < y < SIZE - PAD:
            dots.append((x, y))

    for i, (x1, y1) in enumerate(dots):
        for x2, y2 in dots[i + 1:i + 3]:
            dist = math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
            if dist < SIZE * 0.12:
                draw.line([(x1, y1), (x2, y2)],
                          fill=(100, 80, 200, 15), width=1)

    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))


def draw_bottom_reflection(img):
    """Subtle light reflection at the bottom of the icon."""
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    for i in range(60):
        y = SIZE - PAD - 20 + i
        if y >= SIZE:
            break
        alpha = int(8 * (1 - i / 60))
        draw.line([(PAD + 100, y), (SIZE - PAD - 100, y)],
                  fill=(100, 80, 200, alpha))

    img.paste(Image.alpha_composite(img.convert('RGBA'), overlay))


def apply_squircle_mask(img):
    """Apply macOS-style continuous corner (squircle) mask."""
    mask = Image.new('L', (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)

    # macOS icon corner radius is ~22.37% of icon size
    corner_r = int(SIZE * 0.2237)
    draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1],
                           radius=corner_r, fill=255)

    # Slight feather
    mask = mask.filter(ImageFilter.GaussianBlur(1))

    result = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def generate_icon():
    """Main icon generation pipeline."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    print("  Drawing background...")
    draw_rounded_rect_bg(img)

    print("  Drawing connection dots...")
    draw_connection_dots(img, CENTER, int(SIZE * 0.48))

    print("  Drawing shield...")
    shield_data = draw_shield(img)

    print("  Drawing speed arc...")
    arc_cx, arc_cy = draw_speed_arc(img, CENTER, int(SIZE * 0.48))

    print("  Drawing lock icon...")
    draw_lock_icon(img, CENTER, int(SIZE * 0.48))

    print("  Drawing reflection...")
    draw_bottom_reflection(img)

    print("  Applying squircle mask...")
    img = apply_squircle_mask(img)

    return img


def export_sizes(master, out_dir):
    """Export all macOS icon sizes from master 1024px image."""
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_64x64.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, px in sizes:
        resized = master.resize((px, px), Image.LANCZOS)
        path = out_dir / filename
        resized.save(str(path), 'PNG')
        print(f"  ✓ {filename} ({px}×{px})")


def create_icns(icon_dir, icns_path):
    """Create .icns file using iconutil (macOS)."""
    # iconutil needs an .iconset directory
    iconset = icon_dir.parent / "VPNTools.iconset"
    iconset.mkdir(exist_ok=True)

    # Map appiconset names to iconset names
    mappings = {
        "icon_16x16.png": "icon_16x16.png",
        "icon_16x16@2x.png": "icon_16x16@2x.png",
        "icon_32x32.png": "icon_32x32.png",
        "icon_32x32@2x.png": "icon_32x32@2x.png",
        "icon_128x128.png": "icon_128x128.png",
        "icon_128x128@2x.png": "icon_128x128@2x.png",
        "icon_256x256.png": "icon_256x256.png",
        "icon_256x256@2x.png": "icon_256x256@2x.png",
        "icon_512x512.png": "icon_512x512.png",
        "icon_512x512@2x.png": "icon_512x512@2x.png",
    }

    for src_name, dst_name in mappings.items():
        src = icon_dir / src_name
        dst = iconset / dst_name
        if src.exists():
            import shutil
            shutil.copy2(str(src), str(dst))

    result = subprocess.run(
        ["iconutil", "--convert", "icns", "--output", str(icns_path), str(iconset)],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"  ✓ {icns_path.name}")
    else:
        print(f"  ✗ iconutil failed: {result.stderr}")

    # Cleanup iconset
    import shutil
    shutil.rmtree(str(iconset), ignore_errors=True)


def main():
    script_dir = Path(__file__).parent
    icon_dir = script_dir / "VPNTools" / "Assets.xcassets" / "AppIcon.appiconset"
    icns_path = script_dir / "VPNTools.icns"

    print("==> Generating VPN Tools icon")
    master = generate_icon()

    # Save master
    master_path = icon_dir / "icon_master_1024.png"
    master.save(str(master_path), 'PNG')
    print(f"  ✓ Master saved: {master_path.name}")

    print("==> Exporting sizes...")
    export_sizes(master, icon_dir)

    print("==> Creating .icns...")
    create_icns(icon_dir, icns_path)

    print("==> Done!")


if __name__ == "__main__":
    main()
