# AGENT.md - Battle Mahjong Poster Script Font & Tooling

This document describes the typography pipeline, architecture, build tooling, and iterative calibration workflow for the custom **Battle Mahjong Poster Script** typeface.

---

## 1. Overview & Architecture

**Battle Mahjong Poster Script** is an authentic, bold, expressive brush-script display typeface created specifically for Battle Mahjong title screens, arcade victory banners, reward callouts, and seasonal event posters.

### Asset & Tooling Layout

```text
Battle-Mahjong/
├── assets/
│   └── fonts/
│       ├── custom/
│       │   └── Battle Mahjong Poster Script/     # 93 authored glyph vector SVGs
│       │       ├── A.svg ... Z.svg
│       │       ├── a.svg ... z.svg
│       │       ├── 0.svg ... 9.svg
│       │       └── [punctuation & symbols].svg
│       ├── battle-mahjong-poster-script.ttf      # TrueType compiled font
│       ├── battle-mahjong-poster-script.otf      # OpenType compiled font
│       ├── battle-mahjong-poster-script.woff2    # Compressed web font
│       ├── battle-mahjong-poster-script.tres     # Godot 4.6 FontFile resource
│       └── specimen.html                         # Interactive typography specimen & testing lab
├── scripts/
│   └── tools/
│       ├── build_custom_font.py                  # Core FontForge font generation script
│       ├── build_font.bat                        # One-click Windows build batch runner
│       ├── optical_kerning.json                  # Authoritative optical kerning table (1,067 pairs)
│       ├── apply_uppercase_kerning.py            # Automated uppercase-to-uppercase (A-Z x A-Z) optical calibrator
│       ├── calibrate_all_phrases.py              # Automated collision detector & optical metric scanner
│       └── calibrate_numbers.py                  # Digit (0-9) & punctuation (comma, period) calibrator
└── tests/
    ├── test_custom_font.gd                       # Godot headless font verification test
    └── test_score_ui_font.gd                     # In-game HUD font variation & shadow style test
```

---

## 2. Prerequisites & Environment Setup

To compile the font from source SVGs and adjust kerning:

1. **FontForge with Python (ffpython)**:
   - Windows Default Location: `C:\Program Files\FontForgeBuilds\bin\ffpython.exe`
   - Linux/macOS: `fontforge -script ...` or `python` with `import fontforge`.
2. **Python 3 with FontTools & Brotli**:
   - `pip install fonttools brotli`
   - Required for automatic `.woff2` compilation from `.ttf`.
3. **Godot Engine 4.6.3 Stable**:
   - For running headless test suite: `godot --headless --path . -s tests/test_custom_font.gd`.

---

## 3. Font Design Metrics & Coordinate System

- **EM Square**: `1000` units
- **Ascent**: `800` units
- **Descent**: `200` units
- **Base Sidebearings**:
  - Left Sidebearing (LSB): `6` units
  - Right Sidebearing (RSB): `6` units
  - Proportional scaling handles variations in individual glyph master widths.
- **Glyph Canvas Geometry**:
  - Source SVG viewBox: `0 0 1000 1000`
  - Glyph baseline is aligned to $y = 800$ in SVG space (FontForge $y = 0$).

---

## 4. How the Build Process Works

Run the build using either command:

```powershell
# Option A: One-click batch runner
.\scripts\tools\build_font.bat

# Option B: Direct ffpython invocation
& "C:\Program Files\FontForgeBuilds\bin\ffpython.exe" scripts/tools/build_custom_font.py
```

### Build Pipeline Steps (`scripts/tools/build_custom_font.py`):
1. **Font Initialization**: Creates a new FontForge font with PostScript name `BattleMahjongPosterScript-Bold`, weight `Bold`, and em-size `1000`.
2. **Glyph Ingestion**: Iterates through uppercase letters (`A-Z`), lowercase letters (`a-z`), numerals (`0-9`), and punctuation (`! ? . , : ; ' " - _ + = / \ ( ) [ ] { } % $ # @ & *`).
3. **Contour Optimization**: Imports each SVG, scales to match the ascent/descent, corrects contour direction, removes overlapping self-intersections, and sets sidebearings.
4. **GPOS Kerning Subtable Generation**:
   - Reads `scripts/tools/optical_kerning.json`.
   - Creates a GPOS kerning pair lookup table (`kern_optical`).
   - Injects kerning offsets between glyph pairs (negative values bring glyphs closer, positive values add space).
5. **Multi-Format Export**:
   - Generates TrueType (`.ttf`) and OpenType (`.otf`).
   - Converts `.ttf` to compressed `.woff2` using `fontTools.ttLib.woff2`.
   - Generates or updates the Godot 4.6 `FontFile` resource (`battle-mahjong-poster-script.tres`).

---

## 5. Iterative Calibration Workflow

When adding new glyphs, tweaking existing SVGs, or refining typography for specific game phrases, follow this iterative cycle:

### Step 1: Edit or Add Source SVGs
- Place or edit SVGs in `assets/fonts/custom/Battle Mahjong Poster Script/`.
- Ensure paths are clean vectors with closed loops.

### Step 2: Recompile the Font
```powershell
.\scripts\tools\build_font.bat
```

### Step 3: Run Automated Collision & Gap Detection
The scanner inspects horizontal raster slices along the optical reading band ($y \in [40, 420]$) and flags any physical contour collision (gap $< -1.5$ px) or excessive optical gaps:
```powershell
# Phrase & letter scanner
python scripts/tools/calibrate_all_phrases.py

# Number & currency/punctuation scanner
python scripts/tools/calibrate_numbers.py
```
This script evaluates 13 core game phrases and 380+ character pairs across:
- *"BATTLE MAHJONG"*
- *"CHAMPION LEAGUE"*
- *"COMBO x8"*
- *"VICTORY ROYALE"*
- *"TILES REVEALED"*
- *"MYSTERY TAVERN"*
- *"HIGH ROLLER"*
- *"DRAGON STRIKE"*
- *"PERFECT CLEAR"*
- *"TRIPLE THREAT"*
- *"STAGE COMPLETE"*
- *"Handgloves"* (traditional font specimen benchmark)
- *"The quick brown fox jumps over the lazy dog"* (complete pangram)

### Step 4: Fine-Tune Kerning in `scripts/tools/optical_kerning.json`
Key typography rules discovered for this brush script:
- **All-Caps Optical Alignment (`FONT`, `STREAK`, `EXTRA TIME`)**:
  - Uppercase letters without kerning leave massive optical voids due to wide bounding-box overhangs (`T`, `F`, `E`, `R`, `I`, `X`).
  - Calibrated via `scripts/tools/apply_uppercase_kerning.py` across all 676 uppercase pairs ($A\text{–}Z \times A\text{–}Z$), generating 641 uppercase pairs (e.g. `"F,O": -150`, `"T,R": -155`, `"E,A": -75`, `"T,I": -150`, `"E,X": -110`, `"M,E": -90`).
  - Maintains strict physical safety clearance ($gap \ge 24$ px) to prevent contour clipping.
- **Capital Overhangs (`T`, `P`, `F`, `V`, `W`, `Y`)**:
  - Lowercase vowels sit beneath the horizontal crossbars or diagonal arms.
  - Require deep negative kerning (e.g. `"T,a": -305`, `"P,a": -100`, `"P,e": -90`, `"V,i": -70`).
- **Ascender & Flourish Offsets (`d`, `L`, `h`, `b`)**:
  - Glyphs with high rightward flourishing ascenders (like `d` with $x \approx 412$ at $y \approx 565$, or `L` with $x \approx 474$ at $y \approx 167$) create wide overall bounding boxes.
  - Vowels following these ascenders must be tucked inward (e.g. `"d,g": -70`, `"L,e": -10`) while avoiding contour collision at the baseline.
- **Descending Loops (`g`, `j`, `p`, `q`, `y`)**:
  - Letters following descenders should sit cleanly without clipping the descending tail (e.g. `"p,s": -15`, `"o,n": -45`).

### Step 5: Visual In-Browser Verification
Launch the live specimen server (if not already running):
```powershell
python -m http.server 8089 --directory assets/fonts
```
Navigate to:
`http://localhost:8089/specimen.html?v=optical[N]` (bump `N` to bust browser cache).
Inspect:
1. The **Main Display Header**
2. The **Live Interactive Testing Playground** (type any custom phrase, scale from 16px to 120px)
3. The **Phrase Specimen Gallery** (all 13 cards rendered with live GPOS kerning)
4. The **Complete Glyph Grid** (all 93 characters)

### Step 6: Verify in Godot Headless Test Suite
```powershell
godot --headless --path . -s tests/test_custom_font.gd
godot --headless --path . -s tests/ui_smoke_runner.gd
```

---

## 6. Godot Integration

The compiled font is imported into Godot via `assets/fonts/battle-mahjong-poster-script.tres`.

To use in GDScript:
```gdscript
var poster_font: FontFile = load("res://assets/fonts/battle-mahjong-poster-script.tres")
my_label.add_theme_font_override("font", poster_font)
my_label.add_theme_font_size_override("font_size", 48)
```

In `.tscn` scene files:
```text
theme_override_fonts/font = ExtResource("res://assets/fonts/battle-mahjong-poster-script.tres")
theme_override_font_sizes/font_size = 48
```

---

## 7. Future Maintenance & Extension Checklist

When picking up this task in the future:
1. **Adding Accented/International Characters (e.g. `é`, `ü`, `ñ`)**:
   - Add SVGs to `assets/fonts/custom/Battle Mahjong Poster Script/`.
   - Map the unicode codepoint in `build_custom_font.py`.
   - Add appropriate pairs to `optical_kerning.json`.
2. **Adjusting Character Sidebearings vs Kerning**:
   - If a character feels consistently too wide across *all* combinations, adjust its base metrics or SVG viewBox rather than adding dozens of kerning pairs.
   - Use `optical_kerning.json` strictly for contextual pair positioning.
