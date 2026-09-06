"""
Comprehensive optical kerning calibrator for Uppercase-to-Uppercase pairs
in Battle Mahjong Poster Script.
"""

import os
import json
import fontforge

FONT_PATH = os.path.join(os.path.dirname(__file__), "../../assets/fonts/battle-mahjong-poster-script.ttf")
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "optical_kerning.json")

font = fontforge.open(FONT_PATH)

UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

def get_glyph_profile(g):
    pts = [pt for cnt in g.layers[1] for pt in cnt]
    if not pts:
        return None, None
    l_prof = {}
    r_prof = {}
    for y in range(-50, 750, 8):
        xs = [p.x for p in pts if abs(p.y - y) <= 10]
        if xs:
            l_prof[y] = min(xs)
            r_prof[y] = max(xs)
    return l_prof, r_prof

profiles = {}
widths = {}
for c in UPPERCASE:
    g = font[c]
    widths[c] = g.width
    profiles[c] = get_glyph_profile(g)

def evaluate_pair(c1, c2, kern=0):
    l1, r1 = profiles[c1]
    l2, r2 = profiles[c2]
    w1 = widths[c1]
    
    adv = w1 + kern
    common_ys = sorted(set(r1.keys()).intersection(l2.keys()))
    if not common_ys:
        return 999, 999
    
    gaps = []
    for y in common_ys:
        dist = (adv + l2[y]) - r1[y]
        gaps.append(dist)
        
    min_gap = min(gaps)
    # Optical gap in the middle reading band
    mid_gaps = [g for y, g in zip(common_ys, gaps) if 80 <= y <= 560]
    avg_gap = sum(mid_gaps) / len(mid_gaps) if mid_gaps else sum(gaps) / len(gaps)
    return min_gap, avg_gap

def find_best_kern(c1, c2):
    min0, avg0 = evaluate_pair(c1, c2, 0)
    
    # If collision or dangerous clearance (< 20px) at zero kern
    if min0 < 20:
        for k in range(5, 120, 5):
            m, a = evaluate_pair(c1, c2, k)
            if m >= 24:
                return k, m, a
        return 25, evaluate_pair(c1, c2, 25)[0], evaluate_pair(c1, c2, 25)[1]
    
    # If gap is too large, pull together while keeping min_gap >= 24px
    # Target average gap around 230-260px for clean uppercase display
    best_k = 0
    best_m = min0
    best_a = avg0
    
    target_avg = 245.0
    
    # Try negative kerns from -5 down to -340
    for k in range(-5, -340, -5):
        m, a = evaluate_pair(c1, c2, k)
        if m < 24: # Must preserve safe clearance
            break
        best_k = k
        best_m = m
        best_a = a
        if a <= target_avg:
            break
            
    return best_k, best_m, best_a

# Calculate optimal kerning for all uppercase pairs
uppercase_kerns = {}
for c1 in UPPERCASE:
    for c2 in UPPERCASE:
        k, m, a = find_best_kern(c1, c2)
        if k != 0:
            uppercase_kerns[f"{c1},{c2}"] = k

print(f"Generated {len(uppercase_kerns)} uppercase-to-uppercase kerning pairs.")

# Load existing optical_kerning.json
with open(CONFIG_PATH, "r", encoding="utf-8") as f:
    config = json.load(f)

existing_pairs = config.get("pairs", {})
initial_count = len(existing_pairs)

# Merge uppercase pairs into existing pairs
merged_pairs = dict(existing_pairs)
merged_pairs.update(uppercase_kerns)

# Sort alphabetically by key
sorted_pairs = dict(sorted(merged_pairs.items()))

config["pairs"] = sorted_pairs

with open(CONFIG_PATH, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print(f"Successfully updated {CONFIG_PATH}: {initial_count} pairs -> {len(sorted_pairs)} pairs.")

# Verify user-targeted phrases
targeted_words = ["FONT", "STREAK", "EXTRA", "TIME", "SCORE", "BATTLE", "MAHJONG", "READY", "COMBO", "FROZEN"]
print("\n=== VERIFYING TARGETED WORDS ===")
for word in targeted_words:
    print(f"\n--- {word} ---")
    for i in range(len(word) - 1):
        pair = f"{word[i]},{word[i+1]}"
        k = sorted_pairs.get(pair, 0)
        m, a = evaluate_pair(word[i], word[i+1], k)
        m0, a0 = evaluate_pair(word[i], word[i+1], 0)
        print(f"  {pair}: kern={k:+d} | min: {m0:.1f} -> {m:.1f}px | avg: {a0:.1f} -> {a:.1f}px")
