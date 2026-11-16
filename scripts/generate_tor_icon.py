import os
import math
from PIL import Image, ImageDraw, ImageFilter

def render_onionguard_icon(size):
    """
    Renders the Onion Guard premium IoT icon:
    - Deep forest-green (#071D13) and near-black (#06100C) circular badge
    - Luminous emerald (#00D68F) outer ring with subtle neon halo
    - Left side: Concentric curved onion layers / rings in luminous emerald (#00D68F) and cream (#F3F0DF)
    - Right side: Smooth onion bulb contour in luminous emerald
    - Top: Dual vibrant lime (#B6F36B) and emerald sprout
    - Center core: Solid cream/emerald nucleus
    """
    scale = 4  # 4x supersampling for ultra-crisp antialiasing
    s = size * scale
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = s * 0.04
    cx = s * 0.50
    cy = s * 0.53
    r = s * 0.35
    line_w = max(2, int(s * 0.042))

    # 1. Subtle emerald neon outer glow ring
    for offset, alpha in [(s * 0.015, 35), (s * 0.008, 60)]:
        glow_box = [margin - offset, margin - offset, s - margin + offset, s - margin + offset]
        draw.ellipse(glow_box, fill=(0, 214, 143, alpha))

    # 2. Main circular badge background: Deep forest green #071D13
    bg_box = [margin, margin, s - margin, s - margin]
    draw.ellipse(bg_box, fill=(7, 29, 19, 255))

    # 3. Outer ring border in luminous emerald #00D68F
    border_w = max(2, int(s * 0.022))
    draw.ellipse(bg_box, outline=(0, 214, 143, 230), width=border_w)

    # 4. Right half outer contour (smooth outer onion bulb) - Luminous Emerald
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=-90, end=90, fill=(0, 214, 143, 255), width=line_w)

    # 5. Concentric left onion rings (layers of the onion)
    num_layers = 4
    layer_colors = [
        (243, 240, 223, 255),  # Cream #F3F0DF
        (0, 214, 143, 255),    # Emerald #00D68F
        (182, 243, 107, 255),  # Lime #B6F36B
        (0, 214, 143, 255),    # Emerald #00D68F
    ]
    for i in range(1, num_layers + 1):
        cur_r = r * (i / num_layers)
        c = layer_colors[(i - 1) % len(layer_colors)]
        draw.arc([cx - cur_r, cy - cur_r, cx + cur_r, cy + cur_r], start=90, end=270, fill=c, width=line_w)

    # 6. Vertical axis separator line
    draw.line([(cx, cy - r), (cx, cy + r)], fill=(243, 240, 223, 240), width=int(line_w * 0.75))

    # 7. Onion center core (solid bulb nucleus)
    core_r = r * 0.20
    draw.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r], fill=(243, 240, 223, 255))
    inner_dot = core_r * 0.50
    draw.ellipse([cx - inner_dot, cy - inner_dot, cx + inner_dot, cy + inner_dot], fill=(0, 214, 143, 255))

    # 8. Lime & Emerald Sprout at the top
    sprout_base_y = cy - r
    stem_top_x = cx + s * 0.025
    stem_top_y = cy - r - s * 0.16
    draw.polygon([
        (cx - s * 0.035, sprout_base_y),
        (cx + s * 0.035, sprout_base_y),
        (stem_top_x + s * 0.025, stem_top_y),
        (stem_top_x - s * 0.025, stem_top_y),
    ], fill=(182, 243, 107, 255))  # Lime #B6F36B

    # Secondary sprout leaf angling right in emerald #00D68F
    draw.polygon([
        (cx + s * 0.015, sprout_base_y - s * 0.03),
        (cx + s * 0.095, sprout_base_y - s * 0.12),
        (cx + s * 0.035, sprout_base_y - s * 0.08),
    ], fill=(0, 214, 143, 255))

    # Downscale using Lanczos filter for smooth antialiasing
    return img.resize((size, size), Image.Resampling.LANCZOS)

def main():
    targets = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
        'assets/images/tor_logo.png': 512,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
    }

    # Also generate common iOS icon sizes if the asset catalog exists
    ios_sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180]
    for sz in ios_sizes:
        targets[f'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{sz}x{sz}.png'] = sz

    os.makedirs('assets/images', exist_ok=True)

    for path, size in targets.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        icon = render_onionguard_icon(size)
        icon.save(path, format='PNG')
        print(f"Generated {size}x{size} Onion Guard icon at: {path}")

if __name__ == '__main__':
    main()
