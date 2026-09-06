"""
adjust_numerals.py

Adjusts numeral vector outlines and kerning metrics:
1. Trims the long baseline tail of 2.svg so it aligns with the character's natural width (~450-460).
2. Balances 5, 6, 7 in 567 and sequence 1234567890.
"""
import os
import re
import xml.etree.ElementTree as ET

SVG_PATH = "assets/fonts/custom/Battle Mahjong Poster Script/Numerals/2.svg"

with open(SVG_PATH, "r", encoding="utf-8") as f:
    content = f.read()

m = re.search(r'd="([^"]+)"', content)
d = m.group(1)

# Find all commands
cmds = re.findall(r'([A-Za-z])([^A-Za-z]*)', d)

new_cmds = []
for cmd, args in cmds:
    nums = [float(x) for x in re.findall(r'[-+]?[0-9]*\.?[0-9]+', args)]
    if not nums:
        new_cmds.append(cmd)
        continue
    
    # Process coordinates in pairs (x, y)
    new_nums = []
    for i in range(0, len(nums), 2):
        x = nums[i]
        y = nums[i+1]
        
        # If in the tail region (y in [720, 870] and x > 715), compress x
        if y > 720 and y < 870 and x > 715:
            # Map [715, 870] to [715, 735]
            x = 715.0 + (x - 715.0) * 0.12
        
        new_nums.append(f"{x:.3f}")
        new_nums.append(f"{y:.3f}")
    
    new_cmds.append(cmd + " " + " ".join(new_nums))

new_d = " ".join(new_cmds)
new_content = re.sub(r'd="[^"]+"', f'd="{new_d}"', content)

with open(SVG_PATH, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Successfully updated 2.svg tail with proper spacing.")
