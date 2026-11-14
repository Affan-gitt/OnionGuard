import os
import math
from PIL import Image, ImageDraw

def render_tor_onion(size):
    """
    Renders the Tor Project onion logo:
    - Deep Tor purple circular background (#7D4698)
    - Distinctive onion silhouette
    - Left side: Concentric curved onion layers / rings in crisp white
    - Right side: Smooth onion contour in white
    - Top: Characteristic green onion sprout (#58B653)
    - Center core: Solid white nucleus
    """
    scale = 4  # 4x supersampling for high-quality antialiasing
    s = size * scale
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background circular badge
    margin = s * 0.03
    bg_box = [margin, margin, s - margin, s - margin]
    # Tor official purple #7D4698
    draw.ellipse(bg_box, fill=(125, 70, 152, 255))

    cx = s * 0.50
    cy = s * 0.53
    r = s * 0.35
    line_w = max(2, int(s * 0.042))

    # 2. Right half outer contour (smooth outer onion bulb)
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=-90, end=90, fill=(255, 255, 255, 255), width=line_w)

    # 3. Concentric left onion rings (layers of the onion)
    num_layers = 4
    for i in range(1, num_layers + 1):
        cur_r = r * (i / num_layers)
        draw.arc([cx - cur_r, cy - cur_r, cx + cur_r, cy + cur_r], start=90, end=270, fill=(255, 255, 255, 255), width=line_w)

    # 4. Vertical axis separator line (subtle layer boundary)
    draw.line([(cx, cy - r), (cx, cy + r)], fill=(255, 255, 255, 255), width=int(line_w * 0.7))

    # 5. Onion center core (solid white bulb core)
    core_r = r * 0.20
    draw.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r], fill=(255, 255, 255, 255))

    # 6. Green Sprout / Shoot at the top
    sprout_base_y = cy - r
    # Main stem
    stem_top_x = cx + s * 0.02
    stem_top_y = cy - r - s * 0.15
    draw.polygon([
        (cx - s * 0.03, sprout_base_y),
        (cx + s * 0.03, sprout_base_y),
        (stem_top_x + s * 0.025, stem_top_y),
        (stem_top_x - s * 0.025, stem_top_y),
    ], fill=(88, 182, 83, 255)) # Tor green #58B653

    # Small secondary green leaf tip angling right
    draw.polygon([
        (cx + s * 0.01, sprout_base_y - s * 0.04),
        (cx + s * 0.08, sprout_base_y - s * 0.11),
        (cx + s * 0.03, sprout_base_y - s * 0.07),
    ], fill=(112, 198, 102, 255))

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
    }

    os.makedirs('assets/images', exist_ok=True)

    for path, size in targets.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        icon = render_tor_onion(size)
        icon.save(path, format='PNG')
        print(f"Generated {size}x{size} Tor icon at: {path}")

if __name__ == '__main__':
    main()
