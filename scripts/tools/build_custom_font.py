#!/usr/bin/env python3
"""
build_custom_font.py

Builds a TrueType / OpenType / WOFF2 font from individual SVG glyph files
using FontForge Python (ffpython).

Usage:
  ffpython scripts/tools/build_custom_font.py
  ffpython scripts/tools/build_custom_font.py --svg-dir "path/to/svgs" --name "My Font"
"""

import argparse
import glob
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET

# FontForge Python module check
try:
    import fontforge
    import psMat
except ImportError:
    print("ERROR: This script must be run using FontForge's Python interpreter (ffpython).")
    print("Example: & 'C:\\Program Files\\FontForgeBuilds\\bin\\ffpython.exe' scripts/tools/build_custom_font.py")
    sys.exit(1)


# Mapping from SVG filename (without .svg) to Unicode codepoints and glyph names
SYMBOL_MAP = {
    "ampersand": (0x26, "ampersand"),
    "apostrophe": (0x27, "quotesingle"),
    "asciicircum": (0x5E, "asciicircum"),
    "asterisk": (0x2A, "asterisk"),
    "asteriskalt": (0x273B, "uni273B"),  # ✻ Teardrop-Spoked Asterisk
    "at": (0x40, "at"),
    "backslash": (0x5C, "backslash"),
    "braceleft": (0x7B, "braceleft"),
    "braceright": (0x7D, "braceright"),
    "bracketleft": (0x5B, "bracketleft"),
    "bracketright": (0x5D, "bracketright"),
    "colon": (0x3A, "colon"),
    "comma": (0x2C, "comma"),
    "dollar": (0x24, "dollar"),
    "equals": (0x3D, "equal"),
    "exclamationpoint": (0x21, "exclam"),
    "greater": (0x3E, "greater"),
    "heart": (0x2665, "blackheartsuit"),  # ♥ Black Heart Suit
    "hyphen": (0x2D, "hyphen"),
    "less": (0x3C, "less"),
    "numbersign": (0x23, "numbersign"),
    "parenleft": (0x28, "parenleft"),
    "parenright": (0x29, "parenright"),
    "percent": (0x25, "percent"),
    "period": (0x2E, "period"),
    "plus": (0x2B, "plus"),
    "questionmark": (0x3F, "question"),
    "quotedbl": (0x22, "quotedbl"),
    "semicolon": (0x3B, "semicolon"),
    "slash": (0x2F, "slash"),
    "underscore": (0x5F, "underscore"),
}

# Common alias codepoints to map to existing glyphs for seamless typing
EXTRA_ALIASES = {
    # Typography quotes & dashes pointing to existing glyphs
    0x2018: 0x27,  # ‘ left single quote -> quotesingle
    0x2019: 0x27,  # ’ right single quote -> quotesingle
    0x201C: 0x22,  # “ left double quote -> quotedbl
    0x201D: 0x22,  # ” right double quote -> quotedbl
    0x2013: 0x2D,  # – en-dash -> hyphen
    0x2014: 0x2D,  # — em-dash -> hyphen
    0x2212: 0x2D,  # − minus -> hyphen
    0x2764: 0x2665, # ❤ heavy black heart -> ♥ blackheartsuit
    0x2731: 0x273B, # ✱ heavy asterisk -> asteriskalt
}


def sanitize_svg(src_path, dst_path):
    """
    Strips background/artboard rectangles with white fill from SVG exports,
    and filters out any stray subpaths outside the 1000x1200 artboard boundaries.
    """
    tree = ET.parse(src_path)
    root = tree.getroot()

    to_remove = []
    for parent in root.iter():
        for child in list(parent):
            fill = child.attrib.get("fill", "").strip().lower()
            # If element has a white fill, mark for removal
            if fill in ("white", "#ffffff", "#fff", "rgb(255,255,255)", "rgb(255, 255, 255)"):
                to_remove.append((parent, child))
            # Or if it is a rect spanning the full viewBox width/height
            elif child.tag.endswith("rect") and child.attrib.get("width") == "1000" and child.attrib.get("height") == "1200":
                to_remove.append((parent, child))

    for parent, child in to_remove:
        try:
            parent.remove(child)
        except ValueError:
            pass

    # Filter out external stray subpaths (e.g. from canvas exports containing other letters)
    for elem in root.iter():
        if elem.tag.endswith("path") and "d" in elem.attrib:
            d = elem.attrib["d"]
            subpaths = re.findall(r"M[^Z]*Z", d)
            if len(subpaths) > 1:
                kept = []
                for sp in subpaths:
                    nums = [float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", sp)]
                    xs, ys = nums[0::2], nums[1::2]
                    if xs and ys:
                        minx, maxx = min(xs), max(xs)
                        miny, maxy = min(ys), max(ys)
                        # Keep only subpaths within artboard margins (0..1000, 0..1200)
                        if minx >= -100 and maxx <= 1100 and miny >= -100 and maxy <= 1300:
                            kept.append(sp)
                if kept:
                    elem.attrib["d"] = " ".join(kept)

    tree.write(dst_path)


def resolve_glyph_info(filepath):
    """
    Determines Unicode codepoint and glyph name from filepath,
    supporting nested directories (e.g. Lowercase/, Uppercase/, Numerals/, Punctuation/).
    """
    parent = os.path.basename(os.path.dirname(filepath)).lower()
    base = os.path.splitext(os.path.basename(filepath))[0]

    # Single digit '0'-'9'
    if len(base) == 1 and base.isdigit():
        return ord(base), f"zero" if base == '0' else f"uni003{base}"

    # Explicit Lowercase subfolder
    if parent == "lowercase" and len(base) == 1 and base.isalpha():
        char = base.lower()
        return ord(char), char

    # Explicit Uppercase subfolder
    if parent == "uppercase" and len(base) == 1 and base.isalpha():
        char = base.upper()
        return ord(char), char

    # Single uppercase letter 'A'-'Z'
    if len(base) == 1 and base.isupper() and base.isalpha():
        return ord(base), base

    # Single lowercase letter 'a'-'z'
    if len(base) == 1 and base.islower() and base.isalpha():
        return ord(base), base

    # Known symbols
    if base.lower() in SYMBOL_MAP:
        return SYMBOL_MAP[base.lower()]

    print(f"Warning: Unknown glyph mapping for '{filepath}'. Skipping.")
    return None, None


def get_sidebearings(base_name, default_lsb=6, default_rsb=6):
    """
    Returns custom (LSB, RSB) based on glyph category for optimal tight spacing.
    """
    base = base_name.lower()
    if base in ("period", "comma", "colon", "semicolon"):
        return 4, 4
    if base in ("apostrophe", "quotedbl"):
        return 3, 3
    if base in ("hyphen", "underscore", "plus", "equals"):
        return 5, 5
    if base in ("parenleft", "parenright", "bracketleft", "bracketright", "braceleft", "braceright"):
        return 4, 4
    return default_lsb, default_rsb


def build_font(
    svg_dir,
    output_dir,
    font_name="Battle Mahjong Poster Script",
    font_family="Battle Mahjong Poster Script",
    font_weight="Regular",
    em_units=1000,
    ascent=800,
    descent=200,
    default_lsb=6,
    default_rsb=6,
    space_width=220,
):
    print("=" * 60)
    print(f"Building Font: {font_name} ({font_weight})")
    print(f"SVG Source:    {svg_dir}")
    print(f"Output Dir:    {output_dir}")
    print("=" * 60)

    os.makedirs(output_dir, exist_ok=True)
    svg_files = sorted(glob.glob(os.path.join(svg_dir, "**", "*.svg"), recursive=True))
    if not svg_files:
        print(f"ERROR: No SVG files found in {svg_dir}")
        sys.exit(1)

    print(f"Found {len(svg_files)} SVG glyph files across directories.")

    # Initialize FontForge font
    font = fontforge.font()
    font.fontname = font_name.replace(" ", "")
    font.familyname = font_family
    font.fullname = f"{font_family} {font_weight}".strip()
    font.weight = font_weight
    font.em = em_units
    font.ascent = ascent
    font.descent = descent

    # Set encoding to Unicode Full
    font.encoding = "UnicodeFull"

    # Temporary directory for sanitized SVGs
    temp_dir = tempfile.mkdtemp(prefix="font_svg_")
    imported_codepoints = {}

    try:
        # 1. Import SVG outlines
        for svg_path in svg_files:
            fname = os.path.basename(svg_path)
            parent_dir = os.path.basename(os.path.dirname(svg_path))
            base_name = os.path.splitext(fname)[0]
            code, gname = resolve_glyph_info(svg_path)
            if code is None:
                continue

            # Prefix temp file with parent directory to avoid case-insensitive collisions on Windows
            clean_svg = os.path.join(temp_dir, f"clean_{parent_dir}_{fname}")
            sanitize_svg(svg_path, clean_svg)

            glyph = font.createChar(code, gname)
            glyph.importOutlines(clean_svg)

            # Cleanup path geometry
            glyph.removeOverlap()
            glyph.correctDirection()

            # Measure contour bounds
            bbox = glyph.boundingBox()
            xmin, ymin, xmax, ymax = bbox

            # If glyph contains vector paths, calculate proportional sidebearings
            if (xmax - xmin) > 0.001:
                lsb, rsb = get_sidebearings(base_name, default_lsb, default_rsb)
                # Shift horizontally to align left edge with LSB
                dx = lsb - xmin
                glyph.transform(psMat.translate(dx, 0))
                # Set advance width
                glyph.width = int(round((xmax - xmin) + lsb + rsb))
            else:
                glyph.width = space_width

            imported_codepoints[code] = glyph
            if os.path.exists(clean_svg):
                os.remove(clean_svg)

        print(f"Imported {len(imported_codepoints)} vector glyphs.")

        # 2. Add Space Character (0x20)
        space_glyph = font.createChar(0x20, "space")
        space_glyph.width = space_width

        # 3. Add Lowercase 'a'-'z' via Component References to Uppercase 'A'-'Z' only if missing
        mapped_lower_count = 0
        for upper_code in range(ord('A'), ord('Z') + 1):
            lower_code = upper_code + 32  # 'a' - 'z'
            if lower_code not in imported_codepoints and upper_code in imported_codepoints:
                upper_glyph = imported_codepoints[upper_code]
                lower_char = chr(lower_code)
                lower_glyph = font.createChar(lower_code, lower_char)
                lower_glyph.addReference(upper_glyph.glyphname)
                lower_glyph.width = upper_glyph.width
                mapped_lower_count += 1
        if mapped_lower_count > 0:
            print(f"Mapped {mapped_lower_count} missing lowercase characters to uppercase references.")
        else:
            print("All 26 lowercase characters loaded from distinct SVG files.")

        # 4. Add Extra Aliases (smart quotes, dashes, alt symbols)
        mapped_alias_count = 0
        for target_code, source_code in EXTRA_ALIASES.items():
            if source_code in imported_codepoints:
                source_glyph = imported_codepoints[source_code]
                alias_glyph = font.createChar(target_code)
                alias_glyph.addReference(source_glyph.glyphname)
                alias_glyph.width = source_glyph.width
                mapped_alias_count += 1
        print(f"Mapped {mapped_alias_count} typographic aliases (curly quotes, dashes, symbols).")

        # 5. Apply Optical Kerning Pairs (GPOS 'kern' feature)
        kerning_config_path = os.path.join(os.path.dirname(__file__), "optical_kerning.json")
        applied_kern_count = 0
        if os.path.exists(kerning_config_path):
            try:
                with open(kerning_config_path, "r", encoding="utf-8") as kf:
                    kern_data = json.load(kf)
                pairs = kern_data.get("pairs", {})
                if pairs:
                    # Create GPOS lookup and subtable for pair kerning
                    font.addLookup("kern_feature", "gpos_pair", (), (("kern", (("latn", ("dflt")),)),))
                    font.addLookupSubtable("kern_feature", "kern_subtable")

                    def resolve_glyph(token):
                        token = token.strip()
                        if token in ("comma", ","):
                            return font[ord(',')] if ord(',') in font else None
                        if token in ("period", "."):
                            return font[ord('.')] if ord('.') in font else None
                        if len(token) == 1:
                            code = ord(token)
                            if code in font:
                                return font[code]
                        if token in font:
                            return font[token]
                        return None

                    for pair_key, offset in pairs.items():
                        # Parse pair key handling comma as either token
                        if pair_key.startswith(",,"):
                            c1_token, c2_token = ",", pair_key[2:]
                        elif pair_key.endswith(",,"):
                            c1_token, c2_token = pair_key[:-2], ","
                        elif "," in pair_key:
                            parts = pair_key.split(",", 1)
                            c1_token, c2_token = parts[0], parts[1]
                        else:
                            continue

                        g1 = resolve_glyph(c1_token)
                        g2 = resolve_glyph(c2_token)
                        if g1 is not None and g2 is not None:
                            g1.addPosSub("kern_subtable", g2.glyphname, 0, 0, offset, 0, 0, 0, 0, 0)
                            applied_kern_count += 1
                print(f"Applied {applied_kern_count} optical kerning pairs from optical_kerning.json.")
            except Exception as ke:
                print(f"Notice: Could not load optical_kerning.json: {ke}")
        else:
            print("Notice: No optical_kerning.json found; skipping custom kerning pairs.")

        # 6. OS/2 & Font Metrics Normalization
        font.os2_typoascent_add = 0
        font.os2_typodescent_add = 0
        font.os2_winascent_add = 0
        font.os2_windescent_add = 0
        font.hhea_ascent_add = 0
        font.hhea_descent_add = 0

        font.os2_typoascent = ascent
        font.os2_typodescent = -descent
        font.os2_winascent = ascent
        font.os2_windescent = descent
        font.hhea_ascent = ascent
        font.hhea_descent = -descent
        font.hhea_linegap = 0
        font.os2_typolinegap = 0

        # 7. Generate Font Files
        slug = font_family.lower().replace(" ", "-")
        ttf_path = os.path.join(output_dir, f"{slug}.ttf")
        otf_path = os.path.join(output_dir, f"{slug}.otf")
        woff2_path = os.path.join(output_dir, f"{slug}.woff2")

        font.generate(ttf_path)
        print(f"  -> Generated TTF:   {ttf_path} ({os.path.getsize(ttf_path):,} bytes)")

        try:
            font.generate(otf_path)
            print(f"  -> Generated OTF:   {otf_path} ({os.path.getsize(otf_path):,} bytes)")
        except Exception as e:
            print(f"  -> Notice (OTF): {e}")

        try:
            font.generate(woff2_path)
            print(f"  -> Generated WOFF2: {woff2_path} ({os.path.getsize(woff2_path):,} bytes)")
        except Exception as e:
            print(f"  -> Notice (WOFF2): {e}")

        print("\nSUCCESS: Custom font generation completed!")

    finally:
        # Clean up temporary directory
        if os.path.exists(temp_dir):
            for f in os.listdir(temp_dir):
                try:
                    os.remove(os.path.join(temp_dir, f))
                except OSError:
                    pass
            try:
                os.rmdir(temp_dir)
            except OSError:
                pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate font from SVG glyph files.")
    parser.add_argument(
        "--svg-dir",
        default=os.path.join("assets", "fonts", "custom", "Battle Mahjong Poster Script"),
        help="Path to directory containing SVG glyph files.",
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join("assets", "fonts"),
        help="Path to output font directory.",
    )
    parser.add_argument(
        "--name",
        default="Battle Mahjong Poster Script",
        help="Font family name.",
    )
    parser.add_argument(
        "--lsb",
        type=int,
        default=6,
        help="Default left sidebearing (padding in font units).",
    )
    parser.add_argument(
        "--rsb",
        type=int,
        default=6,
        help="Default right sidebearing (padding in font units).",
    )
    parser.add_argument(
        "--space-width",
        type=int,
        default=220,
        help="Advance width for space character.",
    )
    args = parser.parse_args()

    build_font(
        svg_dir=args.svg_dir,
        output_dir=args.output_dir,
        font_name=args.name,
        font_family=args.name,
        default_lsb=args.lsb,
        default_rsb=args.rsb,
        space_width=args.space_width,
    )
