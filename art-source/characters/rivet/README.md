# Rivet reaction assets

Reference: the user's generated character storyboard, preserved at `../reaction-reference.jpg`. Rivet is the first CPU personality for B10; Mei, Uncle Bao, and Nix are not yet implemented.

Built-in image generation produced `confident.png` and `frustrated.png` as transparent PNG masters. Runtime copies are under `game-assets/characters/rivet/`, imported with a 512-pixel limit and mipmaps. The original generated outputs remain in the Codex generated-images directory. No dialogue is baked into either image. A missing expression falls back to the default portrait.

## Confident prompt

Use case: background-extraction / game character asset. Using the supplied Battle Mahjong character reference, create one isolated transparent-background waist-up cutout of RIVET, the white/silver spiky-haired chibi anime rival with brown bronze goggles on their head, teal high collar jacket, warm amber eyes, black fingerless gloves. Preserve the reference's character identity, warm textured cel coloring, lively thick black manga ink outlines and cheeky cocky grin. Pose from the CPU ATTACKS YOU / bottom right panel: dynamic hand extended toward viewer, facing slightly left toward gameplay. Whole head, hair and hands inside the frame, generous 5% transparent margin, waist terminates cleanly at bottom. No text, no speech bubble, no tiles, no background, no UI, no other characters. Actual transparent alpha background, production game sprite, one character only. Save a PNG.

## Frustrated prompt

Use case: identity-preserve, game reaction sprite variant. Edit the supplied transparent Rivet sprite to a shocked frustrated expression for losing/taking a big hit, matching the reference character exactly. Same silver spiky hair, bronze goggles, teal jacket, warm thick manga ink and cel shading. Eyebrows raised inward, eyes wide, mouth open in an exasperated protest, both fingerless-gloved hands raised near chest. Keep the same waist-up scale, facing slightly toward left, whole hair/hands inside canvas with transparent margin. No text, no bubbles, no effects, no background. Preserve genuine transparent alpha. One isolated character PNG.
