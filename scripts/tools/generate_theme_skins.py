import json
import os

default_path = "game-assets/tiles/default/skin.json"
with open(default_path, "r", encoding="utf-8") as f:
    default_manifest = json.load(f)

themes = {
    "neon_nights": {
        "display_name": "Neon Nights",
        "base_presentation": {
            "base_tint": [0.22, 0.23, 0.28, 1.0],
            "bevel_rim_color": [0.0, 0.95, 1.0, 0.90],
            "edge_glow_intensity": 0.85,
            "face_tint": [1.0, 1.0, 1.0, 1.0],
            "back_tint": [0.45, 0.25, 0.65, 1.0],
            "selection_glow_color": [0.0, 0.95, 1.0, 0.65]
        },
        "layout_presentation": {
            "adjacent_gap_ratio": -0.025,
            "ink_outline_color": [0.0, 0.75, 0.95, 0.85],
            "ink_outline_expansion_ratio": [0.018, 0.014],
            "ink_outline_offset_ratio": [-0.002, 0.003]
        },
        "depth_presentation": {
            "lowest_layer_brightness": 0.70,
            "near_top_layer_brightness": 0.90,
            "blocked_brightness_multiplier": 0.82,
            "blocked_desaturation": 0.75,
            "blocked_overlay_color": [0.05, 0.06, 0.10, 0.55],
            "shadow_asset": "res://game-assets/tiles/default/tile_shadow_soft.png",
            "shadow_opacity": 0.68,
            "shadow_offset_ratio": [0.02, 0.17],
            "shadow_expansion_ratio": [0.06, 0.10],
            "contact_shadow_opacity": 0.80,
            "contact_shadow_offset_ratio": [0.005, 0.045],
            "layer_offset_ratio": [0.0, -0.095]
        }
    },
    "imperial_jade": {
        "display_name": "Imperial Jade",
        "base_presentation": {
            "base_tint": [0.32, 0.62, 0.48, 1.0],
            "bevel_rim_color": [1.0, 0.84, 0.25, 0.75],
            "edge_glow_intensity": 0.50,
            "face_tint": [1.0, 0.98, 0.92, 1.0],
            "back_tint": [0.25, 0.50, 0.38, 1.0],
            "selection_glow_color": [1.0, 0.84, 0.25, 0.55]
        },
        "layout_presentation": {
            "adjacent_gap_ratio": -0.025,
            "ink_outline_color": [0.08, 0.20, 0.14, 0.85],
            "ink_outline_expansion_ratio": [0.018, 0.014],
            "ink_outline_offset_ratio": [-0.002, 0.003]
        },
        "depth_presentation": {
            "lowest_layer_brightness": 0.70,
            "near_top_layer_brightness": 0.90,
            "blocked_brightness_multiplier": 0.82,
            "blocked_desaturation": 0.75,
            "blocked_overlay_color": [0.06, 0.14, 0.10, 0.50],
            "shadow_asset": "res://game-assets/tiles/default/tile_shadow_soft.png",
            "shadow_opacity": 0.58,
            "shadow_offset_ratio": [0.02, 0.17],
            "shadow_expansion_ratio": [0.06, 0.10],
            "contact_shadow_opacity": 0.70,
            "contact_shadow_offset_ratio": [0.005, 0.045],
            "layer_offset_ratio": [0.0, -0.095]
        }
    },
    "kawaii_pop": {
        "display_name": "Kawaii Pop",
        "base_presentation": {
            "base_tint": [1.0, 0.86, 0.92, 1.0],
            "bevel_rim_color": [1.0, 0.45, 0.75, 0.60],
            "edge_glow_intensity": 0.40,
            "face_tint": [1.0, 0.96, 0.98, 1.0],
            "back_tint": [1.0, 0.65, 0.80, 1.0],
            "selection_glow_color": [1.0, 0.35, 0.70, 0.50]
        },
        "layout_presentation": {
            "adjacent_gap_ratio": -0.025,
            "ink_outline_color": [0.35, 0.12, 0.22, 0.80],
            "ink_outline_expansion_ratio": [0.018, 0.014],
            "ink_outline_offset_ratio": [-0.002, 0.003]
        },
        "depth_presentation": {
            "lowest_layer_brightness": 0.70,
            "near_top_layer_brightness": 0.90,
            "blocked_brightness_multiplier": 0.82,
            "blocked_desaturation": 0.75,
            "blocked_overlay_color": [0.20, 0.08, 0.14, 0.45],
            "shadow_asset": "res://game-assets/tiles/default/tile_shadow_soft.png",
            "shadow_opacity": 0.55,
            "shadow_offset_ratio": [0.02, 0.17],
            "shadow_expansion_ratio": [0.06, 0.10],
            "contact_shadow_opacity": 0.65,
            "contact_shadow_offset_ratio": [0.005, 0.045],
            "layer_offset_ratio": [0.0, -0.095]
        }
    },
    "vintage_washi": {
        "display_name": "Vintage Washi",
        "base_presentation": {
            "base_tint": [0.92, 0.86, 0.76, 1.0],
            "bevel_rim_color": [0.48, 0.38, 0.28, 0.50],
            "edge_glow_intensity": 0.0,
            "face_tint": [0.95, 0.90, 0.84, 1.0],
            "back_tint": [0.68, 0.50, 0.35, 1.0],
            "selection_glow_color": [0.95, 0.65, 0.30, 0.45]
        },
        "layout_presentation": {
            "adjacent_gap_ratio": -0.025,
            "ink_outline_color": [0.22, 0.16, 0.12, 0.88],
            "ink_outline_expansion_ratio": [0.018, 0.014],
            "ink_outline_offset_ratio": [-0.002, 0.003]
        },
        "depth_presentation": {
            "lowest_layer_brightness": 0.70,
            "near_top_layer_brightness": 0.90,
            "blocked_brightness_multiplier": 0.82,
            "blocked_desaturation": 0.75,
            "blocked_overlay_color": [0.15, 0.12, 0.10, 0.48],
            "shadow_asset": "res://game-assets/tiles/default/tile_shadow_soft.png",
            "shadow_opacity": 0.60,
            "shadow_offset_ratio": [0.02, 0.17],
            "shadow_expansion_ratio": [0.06, 0.10],
            "contact_shadow_opacity": 0.72,
            "contact_shadow_offset_ratio": [0.005, 0.045],
            "layer_offset_ratio": [0.0, -0.095]
        }
    }
}

for theme_id, overrides in themes.items():
    theme_manifest = dict(default_manifest)
    theme_manifest["id"] = theme_id
    theme_manifest["display_name"] = overrides["display_name"]
    theme_manifest["base_presentation"] = overrides["base_presentation"]
    theme_manifest["layout_presentation"] = overrides["layout_presentation"]
    theme_manifest["depth_presentation"] = overrides["depth_presentation"]

    out_dir = f"game-assets/tiles/{theme_id}"
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, "skin.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(theme_manifest, f, indent=2)
    print(f"Generated skin manifest: {out_file}")
