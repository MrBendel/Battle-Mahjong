# Performance Optimization Plan

## Purpose

Keep Battle Mahjong responsive on supported phones while preserving deterministic gameplay, portrait-first layout topology, visual readability, and the production art pipeline.

Optimization work must be driven by measurements from representative Android hardware. Desktop and headless results remain useful for correctness and CPU comparisons, but they do not predict mobile GPU fill rate, thermal behavior, or frame pacing.

This document is an implementation backlog, not a separate gameplay milestone. Work should remain inside the active milestone boundary unless an optimization requires an explicit architectural decision.

## Constraints

- Do not move presentation timing, animation state, or device capability into `GameDefinition`, transactions, or replay data.
- Do not change stable layout slots, selectability, matching, seeded randomness, or Shuffle results.
- Preserve portrait and landscape presentation and safe-area behavior.
- Preserve orientation-specific tile geometry and skin independence.
- Prefer measured, incremental changes over a speculative Board rewrite.
- Compare release or release-like Android exports. Editor and debug instrumentation may materially affect results.

## Representative Scenarios

Capture the same scenarios before and after each optimization batch:

1. Fresh 96-tile Board idle for ten seconds.
2. Ordinary tile selection and Board-to-Tray transfer.
3. Natural pair landing, collision, removal, and queue compaction.
4. Hint glow on two tiles.
5. Shuffle flip-down, visible reposition, and flip-up.
6. Pause, background, foreground recovery, and Resume.
7. Late-game Board with relatively few active tiles.

At minimum, test the project’s primary Android device and one lower-performance or emulated profile when available. Record viewport size, renderer, build type, Android version, refresh rate, and whether the device was thermally throttled.

## Metrics

Record a short baseline table in this document or a linked artifact before changing the renderer:

- median, p95, and worst frame time;
- frames exceeding 16.7 ms and 33.3 ms;
- CPU process and physics time;
- render CPU and GPU time where available;
- 2D draw calls or closest available rendering counters;
- live node, object, and orphan-node counts;
- transient allocations or node creation during each animation;
- texture and total memory;
- observed input latency or dropped-touch behavior.

Use Godot’s Profiler, Visual Profiler, Monitors, and Android tooling such as `adb shell dumpsys gfxinfo` where useful. A small development-only performance capture utility is acceptable if it samples existing engine monitors and does not enter exported production UI by default.

Target steady 60 Hz presentation on representative hardware: p95 below 16.7 ms during ordinary play and no sustained frames above 33.3 ms during short full-Board effects. Establish the real baseline before treating these targets as release gates.

## Current Rendering Cost Centers

The 96-tile Board currently uses one `Button` and up to nine child `CanvasItem` controls per physical tile: shadow, ink silhouette, ceramic base, back, back design, face, hint glow, blocked overlay, and modifier. Not every child draws in every state, but the node count, transparent overdraw, texture changes, and refresh work are material on mobile.

`BoardView.refresh()` also performs work with different invalidation frequencies in one pass. It recomputes gameplay-derived visual state, reapplies textures and styles, recalculates all geometry, configures child presentation, and sorts input order. Normal selection changes visual state but does not change the authored or dynamic slot positions of surviving tiles.

The optimized Shuffle path is the reference for large synchronized effects: one batched flip tween, one batched position tween, and one batched reveal tween. It must not return to per-tile blur nodes or per-tile tween creation.

## Batch 0: Instrumentation

Goal: identify whether the current bottleneck is GDScript/UI traversal, rendering submission, mobile fill rate, transient allocation, or a combination.

- Add a repeatable on-device capture workflow for the representative scenarios.
- Record a baseline before implementing later batches.
- Add optional counters around Board refresh, layout, style creation, preview creation, and Shuffle phases.
- Confirm whether full-resolution transparent tile layers are fill-rate limited by comparing frame time at reduced render resolution.
- Confirm whether frame spikes correlate with object creation or texture/material state changes.

Complete when the next optimization can be chosen from evidence rather than feel alone.

## Batch 1: Refresh and Allocation

Goal: reduce main-thread work without changing the rendered result.

1. Cache immutable `StyleBox`, material, color, and skin presentation resources instead of constructing them during each tile refresh.
2. Assign physical-tile face, base, back, and modifier textures during Board construction or skin/orientation invalidation. Refresh should primarily change visibility, modulation, and input state.
3. Split Board visual-state refresh from geometry layout. Recalculate geometry only after resize, orientation/skin changes, game replacement, or Shuffle slot remapping.
4. Re-sort tile input children only when dynamic slot mapping or layer order changes.
5. Avoid repeating `configure_modifier_art()`, safe-area math, and static texture lookup for every tile on every selection.
6. Keep reusable animation nodes or previews where profiling shows allocation spikes; do not pool objects without a measured benefit.

Validation:

- Existing simulation and UI smoke suites pass.
- Board rectangles, child order, selectability presentation, and screenshots remain equivalent.
- Ordinary selection and pair p95 frame time improve or allocation counters materially decrease.

## Batch 2: Overdraw and Texture Work

Goal: reduce transparent layers and mobile fragment cost while preserving the established depth language.

1. Bake the permanent manga-ink silhouette into each orientation-specific ceramic base if visual comparison confirms equivalence.
2. Replace the full-tile blocked overlay texture with modulation or a shared lightweight shader when it can preserve the cool blocked-state distinction.
3. Create hint glow presentation only for currently hinted tiles, or reuse a two-item glow pool.
4. Do not render fully occluded tiles unless the presentation-only depth offset exposes a meaningful physical edge. Verify this against layered screenshots before culling.
5. Audit tile import settings, mipmaps, runtime dimensions, and Android texture formats at the smallest and largest supported display sizes.
6. Keep shadows as an independent ordered primitive while they are required to affect only the layer below.

Validation:

- Selectable tiles retain canonical brightness.
- Blocked, depth-shaded, face-down, hinted, and modified states remain distinct.
- Portrait and landscape screenshots preserve tile edges and layer separation.
- Mobile render time and overdraw-sensitive scenarios improve.

## Batch 3: Atlas and Batching

Goal: let Godot’s 2D renderer batch more tile work with fewer texture state changes.

- Export tile faces into orientation-appropriate atlases with padding and stable face identifiers.
- Use `AtlasTexture` regions or equivalent skin-managed regions without exposing atlas coordinates to gameplay code.
- Atlas modifier, back-design, and small FX textures where their dimensions and filtering requirements are compatible.
- Keep large backgrounds and character art standalone.
- Verify filtering, mip bleeding, and edge padding at phone tile sizes.
- Measure draw calls and frame time before and after; do not retain an atlas conversion that adds complexity without a real rendering improvement.

## Batch 4: Board Renderer Evaluation

Goal: consider a larger rendering architecture only if Batches 1-3 do not meet the measured device target.

Prototype one representative section before migrating the full Board:

- a custom `Control._draw()` renderer using atlas regions and ordered draw commands; or
- grouped `MultiMeshInstance2D` passes for compatible tile primitives.

A custom Board renderer would keep authoritative tile state unchanged while replacing per-tile Controls with compact presentation records and manual hit testing in reverse visual order. It must preserve accessibility hooks, deterministic target routing, hover/press behavior where applicable, animation previews, and stable slot identifiers.

Choose this direction only when profiling shows node traversal, draw submission, or CanvasItem count remains a dominant cost. Document the measured benefit and migration risk before committing to the rewrite.

## Definition of Done

The initial performance program is complete when:

- representative Android baselines and final measurements are recorded;
- ordinary play and full-Board Shuffle meet the agreed frame-time target on representative hardware;
- no optimization changes deterministic state hashes or replay results;
- all core, simulation, responsive, safe-area, and Android screenshot tests pass;
- portrait and landscape visual comparisons show no readability regression;
- transient presentation leaves no leaked nodes, tweens, or orphaned objects;
- future skins can use the same optimized contracts without gameplay-code changes.
