"""
Automated optical kerning calibration and phrase verification tool
for Battle Mahjong Poster Script.
"""

import os
import sys
import json
import fontforge

FONT_PATH = os.path.join(os.path.dirname(__file__), "../../assets/fonts/battle-mahjong-poster-script.ttf")
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "optical_kerning.json")

def build_glyph_profiles(font):
    profiles = {}
    widths = {}
    for g in font.glyphs():
        name = g.glyphname
        # Sample left and right edges across y=-150 to 700 at step 10
        pts = [pt for l in (g.layers[1],) for cnt in l for pt in cnt]
        if not pts:
            continue
        l_prof = {}
        r_prof = {}
        for y in range(-150, 720, 10):
            xs = [p.x for p in pts if abs(p.y - y) <= 12]
            if xs:
                l_prof[y] = min(xs)
                r_prof[y] = max(xs)
        profiles[name] = (l_prof, r_prof, min(p.y for p in pts), max(p.y for p in pts))
        widths[name] = g.width
    return profiles, widths

def calc_gap_profile(w1, prof1, prof2, kern_val):
    l1, r1, ymin1, ymax1 = prof1
    l2, r2, ymin2, ymax2 = prof2
    adv = w1 + kern_val
    common_ys = sorted(set(r1.keys()).intersection(l2.keys()))
    if not common_ys:
        # Check vertical overhang (e.g. T over a)
        return 9999, 9999, False
    
    gaps = []
    collision = False
    for y in common_ys:
        g = (adv + l2[y]) - r1[y]
        gaps.append(g)
        if g < 0:
            collision = True
    
    # Core optical band: between max(ymin1, ymin2) and min(ymax1, ymax2)
    core_gaps = [g for y, g in zip(common_ys, gaps) if y >= 50 and y <= 450]
    if not core_gaps:
        core_gaps = gaps
    
    avg_gap = sum(core_gaps) / len(core_gaps)
    min_gap = min(gaps)
    return min_gap, avg_gap, collision

def main():
    print(f"Loading font from {FONT_PATH}...")
    font = fontforge.open(FONT_PATH)
    profiles, widths = build_glyph_profiles(font)
    print(f"Loaded profiles for {len(profiles)} glyphs.")

    # Load existing kerning pairs
    existing_pairs = {}
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            existing_pairs = data.get("pairs", {})

    # Key manually vetted pairs to preserve exactly or prioritize
    locked_pairs = {
        "T,a": -305,
        "T,r": -300,
        "T,h": -260,
        "T,e": -295,
        "T,o": -295,
        "T,u": -290,
        "T,i": -280,
        "T,y": -285,
        "T,w": -285,
        "P,o": -85,
        "P,a": -100,
        "P,e": -75,
        "P,r": -65,
        "P,u": -70,
        "G,r": -45,
        "C,h": -50,
        "i,p": -60,
        "s,i": 18,
        "w,n": -60,
        "w,m": -40,
        "m,p": -45,
        "p,s": -28,
        "l,a": -45,
        "l,e": -25,
        "l,o": -40,
        "l,y": -45,
        "o,x": -45,
        "o,g": -25,
        "o,p": -40,
        "u,g": -20,
        "n,g": -15,
        "h,j": -20,
        "p,h": -35,
        "n,x": -20,
        "z,y": -15,
        "t,h": -35,
        "d,a": -35,
        "d,g": -70,
        "d,o": -30,
        "d,s": -25,
        "c,k": -15,
        "f,o": -35,
        "j,u": -20,
        "v,e": -60,
        "o,v": 0,
        "r,i": -28,
        "r,n": -40,
        "r,o": -35,
        "p,i": -35,
        "i,o": -35,
        "o,n": -30,
        "h,a": -15,
        "a,m": -10,
        "L,e": -10,
        "L,a": -20,
        "L,o": -20,
        "e,a": 0,
        "a,g": -10,
        "g,u": -25,
        "u,e": -15,
        "Q,u": -25,
        "b,l": -15,
        "b,o": -15,
        "b,r": -15,
        "b,u": -15,
        "g,e": -20,
        "g,o": -25,
        "o,f": -20,
        "o,m": -20,
        "o,o": -15,
        "o,u": -15,
        "o,s": -15,
        "o,z": -18,
        "p,e": -20,
        "p,l": -20,
        "r,t": -15,
        "u,a": -12,
        "u,d": -15,
        "u,m": -15,
        "u,n": -20,
        "u,r": -10,
        "c,h": -15,
        "i,n": -15,
        "f,i": -15,
        "m,b": -15,
    }

    # All phrases to guarantee flawless spacing across
    test_phrases = [
        "The quick brown fox jumps over the lazy dog.",
        "Pack my box with five dozen liquor jugs.",
        "Sphinx of black quartz, judge my vow!",
        "How vexingly quick daft zebras jump!",
        "Battle Mahjong Poster Script",
        "Ready Player One",
        "Game Over! Play Again",
        "High Score: 999,999",
        "Dragon Tile Bonus 100% ♥",
        "Quick Match Tavern Trophy",
        "Bamboo Dots Characters Winds & Dragons",
        "Round 1 Victory!",
        "Total Coins Earned",
        "Champion League",
        "Super Combo Strike!",
        "Level Complete!",
        "Handgloves Hamburgefontsiv"
    ]

    needed_pairs = set()
    for phrase in test_phrases:
        for i in range(len(phrase) - 1):
            c1, c2 = phrase[i], phrase[i+1]
            if c1 != " " and c2 != " ":
                needed_pairs.add((c1, c2))

    # Also add standard uppercase + lowercase combinations
    for u in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        for l in "aeiouy":
            needed_pairs.add((u, l))
    for u in "TFPVWBDKLMR":
        for l in "rlh":
            needed_pairs.add((u, l))

    # Also common digraphs
    common_digraphs = [
        "th", "he", "in", "er", "an", "re", "nd", "at", "on", "nt",
        "ha", "es", "st", "en", "ed", "to", "it", "ou", "ea", "hi",
        "is", "or", "ti", "as", "te", "et", "ng", "of", "al", "de",
        "se", "le", "sa", "si", "so", "su", "qu", "ck", "ch", "sh",
        "wh", "ff", "ll", "ss", "tt", "pp", "oo", "ee", "ps", "pt",
        "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl",
        "pr", "sc", "sk", "sl", "sm", "sn", "sp", "st", "sw", "tr",
        "tw", "wr"
    ]
    for d in common_digraphs:
        needed_pairs.add((d[0], d[1]))

    print(f"Total target pairs to calibrate: {len(needed_pairs)}")

    updated_pairs = dict(existing_pairs)
    adjusted_count = 0

    for c1, c2 in needed_pairs:
        pair_key = f"{c1},{c2}"
        if c1 not in profiles or c2 not in profiles:
            continue

        # Preserve locked pairs
        if pair_key in locked_pairs:
            updated_pairs[pair_key] = locked_pairs[pair_key]
            continue

        w1 = widths[c1]
        prof1 = profiles[c1]
        prof2 = profiles[c2]

        current_k = updated_pairs.get(pair_key, 0)
        min_gap, avg_gap, collision = calc_gap_profile(w1, prof1, prof2, current_k)

        # If collision or min_gap is too small (< 22px):
        if collision or min_gap < 22:
            best_k = current_k
            best_min = min_gap
            # Shift positive until min_gap >= 26
            for test_k in range(current_k + 5, current_k + 60, 5):
                mg, ag, col = calc_gap_profile(w1, prof1, prof2, test_k)
                if mg >= 25 and not col:
                    best_k = test_k
                    best_min = mg
                    break
            if best_k != current_k:
                updated_pairs[pair_key] = best_k
                adjusted_count += 1

        # If min_gap is too wide (> 85px) and avg_gap > 185px:
        elif min_gap > 85 and avg_gap > 180:
            # Shift negative until min_gap is around 55-65 or overhang tucks cleanly
            is_overhang = c1 in "FVWYKPBDL"
            target_min = 50 if not is_overhang else 35
            for test_k in range(current_k - 5, current_k - 220, -5):
                mg, ag, col = calc_gap_profile(w1, prof1, prof2, test_k)
                if col or mg < target_min:
                    break
                best_k = test_k
                best_min = mg
                best_avg = ag
                if mg <= 65 and ag <= 170:
                    break
            if best_k != current_k:
                updated_pairs[pair_key] = best_k
                adjusted_count += 1

    # Final apply for all locked pairs to ensure absolute fidelity
    for k, v in locked_pairs.items():
        updated_pairs[k] = v

    print(f"Calibration finished. Total pairs: {len(updated_pairs)} (Adjusted {adjusted_count} pairs).")

    # Sort pairs alphabetically
    sorted_pairs = dict(sorted(updated_pairs.items()))

    output_data = {
        "description": "Optical kerning pairs for Battle Mahjong Poster Script. Negative values pull characters closer together.",
        "pairs": sorted_pairs
    }

    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2)

    print(f"Successfully wrote updated optical kerning to {CONFIG_PATH}")

if __name__ == "__main__":
    main()
