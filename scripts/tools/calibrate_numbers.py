"""
Script to compute and calibrate optical kerning for digits 0-9 and punctuation (comma, period).
"""
import os
import sys
import json
import fontforge

FONT_PATH = os.path.join(os.path.dirname(__file__), "../../assets/fonts/battle-mahjong-poster-script.ttf")
from calibrate_all_phrases import build_glyph_profiles, calc_gap_profile

font = fontforge.open(FONT_PATH)
profs, widths = build_glyph_profiles(font)

digits = "0123456789"
puncts = ",."

target_kerns = {}

# 1. Digit -> Comma/Period
for d in digits:
    n1 = font[ord(d)].glyphname
    for p in puncts:
        n2 = font[ord(p)].glyphname
        # Find k that gives balanced clearance
        best_k = 0
        best_score = 999999
        for k in range(-250, 60, 5):
            min_g, avg_g, col = calc_gap_profile(widths[n1], profs[n1], profs[n2], k)
            if not col and min_g >= 22:
                # Target average optical gap around 120-150 for small punctuation
                score = abs(avg_g - 135) + abs(min_g - 40)*0.5
                if score < best_score:
                    best_score = score
                    best_k = k
        if best_k != 0:
            target_kerns[f"{d},{p}"] = best_k

# 2. Comma/Period -> Digit
for p in puncts:
    n1 = font[ord(p)].glyphname
    for d in digits:
        n2 = font[ord(d)].glyphname
        best_k = 0
        best_score = 999999
        for k in range(-30, 80, 5):
            min_g, avg_g, col = calc_gap_profile(widths[n1], profs[n1], profs[n2], k)
            if not col and min_g >= 25:
                score = abs(avg_g - 135) + abs(min_g - 45)*0.5
                if score < best_score:
                    best_score = score
                    best_k = k
        if best_k != 0:
            target_kerns[f"{p},{d}"] = best_k

# 3. Digit -> Digit
for d1 in digits:
    n1 = font[ord(d1)].glyphname
    for d2 in digits:
        n2 = font[ord(d2)].glyphname
        min_0, avg_0, col_0 = calc_gap_profile(widths[n1], profs[n1], profs[n2], 0)
        best_k = 0
        best_score = 999999
        # Search range
        for k in range(-150, 60, 5):
            min_g, avg_g, col = calc_gap_profile(widths[n1], profs[n1], profs[n2], k)
            if not col and min_g >= 22:
                # Target optical average around 200-220
                score = abs(avg_g - 210) + max(0, 30 - min_g)*3
                if score < best_score:
                    best_score = score
                    best_k = k
        if abs(best_k) >= 10:
            target_kerns[f"{d1},{d2}"] = best_k

print(f"Generated {len(target_kerns)} number pairs:")
for pair in sorted(target_kerns.keys()):
    print(f'    "{pair}": {target_kerns[pair]},')

phrase = "1,234,567,890.00"
print("\nResults for " + phrase + ":")
for i in range(len(phrase)-1):
    c1, c2 = phrase[i], phrase[i+1]
    name1 = font[ord(c1)].glyphname
    name2 = font[ord(c2)].glyphname
    k = target_kerns.get(f"{c1},{c2}", 0)
    min_g, avg_g, col = calc_gap_profile(widths[name1], profs[name1], profs[name2], k)
    print(f"  {c1} -> {c2}: kern={k:4d}, min={min_g:5.1f}, avg={avg_g:5.1f}, col={col}")

# Update optical_kerning.json
config_path = os.path.join(os.path.dirname(__file__), "optical_kerning.json")
with open(config_path, "r", encoding="utf-8") as f:
    config = json.load(f)

config["pairs"].update(target_kerns)

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)

print(f"Updated {config_path} with {len(target_kerns)} number pairs (Total: {len(config['pairs'])} pairs).")
