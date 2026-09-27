# 1P vs CPU Battle

## Scope and sequence

The [supplied proposal](BATTLE_MODE_PROPOSAL.md) defines the intended B1–B11 sequence. These Battle milestones are distinct from project M1–M11. The user authorized B1 through B10 as the first implementation slices under the game-mode work. Local Battle does not introduce networking, persistence, progression, or a rendered CPU board.

- **B1 — implemented:** standalone Battle definition, state, transactional commands, workload-derived progress, terminal winner, and in-memory replay validation.
- **B2 - implemented:** seeded CPU scheduling and tuning.
- **B3 - implemented:** transaction-driven player charge and outgoing attack queues.
- **B4 - implemented:** delayed incoming queues, symmetric cancellation, and landing handoff records.
- **B5 - implemented:** seeded matching-pair payloads preserved through cancellation and landing.
- **B6 - implemented:** transactional player board insertion, lifted stacks, certified routes, and overflow.
- **B7 - implemented:** exactly-once CPU workload delivery and recovery.
- **B8 - implemented:** Game Hall entry, coordinated playable host, automatic CPU attacks, and shared responsive HUD.
- **B9 - implemented:** attack travel, cancellation, landing feedback, and sound hooks.
- **B10 - implemented:** semantic reaction hooks and Rivet's themeable character presentation.
- **B11 - deferred:** playable balance pass.

## B1 ownership

`scripts/simulation/battle/battle_store.gd` owns one active Battle state and its transaction history. It snapshots a validated dictionary definition at construction. `configuration/battle/prototype.json` supplies the provisional 48-pair workloads and a seed. Starting workloads can differ. Battle rules version 1 preserves the B1 state-only contract. Rules version 2 adds snapshotted CPU tuning; version 3 adds charge tuning; version 4 adds attack-delay tuning; version 5 adds a snapshotted payload vocabulary and size limit; version 6 adds insertion tuning; version 7 adds CPU workload delivery; new defaults use version 8 with CPU charge generation; unknown fields and invalid counts fail closed.

This store has no scenes, wall clock, profile access, or unseeded RNG calls. B6 optionally binds a Mahjong board through the adapter described below. It does not replace the existing Mahjong `GameStore`, read mutable profile choices, or change Quick Play/Tower behavior. The B3 adapter observes committed Mahjong transactions and translates them into Battle commands exactly once; a playable Battle host remains deferred. The Battle command ID must identify that source event; animation callbacks must never author progress. Starting player workload must be derived from the selected game definition at integration time, not assumed to be 48.

Snapshots track each side's cleared/remaining pairs, score, streak, momentum units, attack-charge units, and pending-attack array. Winner and lifecycle status live at the Battle level. Charge stays at zero and queues stay empty in B1; B3 generates player charge and queued attacks; B4 adds delayed delivery and cancellation. `resolving_attack` is reserved but has no transition yet. B2 populates CPU behavior through its own scheduler; no fake attacks are generated.

## Commands and transactions

Every command carries a nonempty unique `id`, `expected_revision`, `type`, and `side` (`player` or `cpu`).

- `clear_pairs` consumes a positive `pair_count` from remaining work and increments cleared work. Over-clears are rejected.
- `add_work` increases remaining work only. This is the workload primitive for a future successful attack landing; it does not insert tiles or enqueue an attack.
- `set_stats` snapshots any nonempty subset of `score`, `streak`, and `momentum_units`. Decreases are legal (for example a streak break or future compensation); counters must remain nonnegative integers.

Counters are bounded at one billion to prevent unbounded arithmetic; this is a serialization/validation limit, not a gameplay tuning rule. All inputs are validated before commit. Accepted transactions contain the definition, original command, and before/after snapshots. Full snapshots keep this first, small model inspectable without introducing a generic mutation framework. Returned state, definition, results, and timeline are deep copies. Duplicate IDs, stale revisions, malformed events, and events after victory are rejected without changes.

`apply_transaction` recomputes the command against the current state and compares the complete record before accepting it. It rejects reordered, duplicated, definition-mismatched, and tampered records atomically. Replay is in-memory typed Variant data in B1; there is no durable JSON/game-record format or persistence implementation yet. CPU randomness uses the snapshotted seed and replayable Battle RNG state, never presentation randomness.

## Progress and finish

For either side: `progress = cleared_pairs / (cleared_pairs + remaining_pairs)`.

The player's race coordinate is `0.5 * progress`; the CPU's is `1 - 0.5 * progress`. Only display helpers use floating point; authoritative work and statistics are integers. Adding work reduces established progress. With no clears, added work increases the total but the marker remains at its starting endpoint.

The first accepted clear leaving zero remaining work commits `player_won` or `cpu_won`. Terminal state freezes all further commands. This provides deterministic first-event-wins ordering; scheduling simultaneous CPU ticks, player inputs, and attack landings is an explicit later integration decision, not an implied player/CPU priority.

## Open decisions before integration

- Tie ordering among simultaneous completion, attack landing, and input events.
- Whether/how pending attacks affect completion eligibility; B1 has no pending attacks.
- Battle policy for the existing automatic endgame clear.
- Hearts, tray failure, defeat, surrender, Undo, consumables, and result application.
- Source-event mapping and correction when Mahjong state is undone.
- B6 insertion schema: dynamic tile identity, stable slot allocation, depth limits, support and solver validation.
- Final meaning of streak bonuses (existing Combo versus timed attack cadence) and CPU momentum.

## Verification

Run `godot --headless --path . --script res://tests/battle_state_runner.gd` from the repository root. It covers both race directions and winners, increased work, independent stats, immutable boundaries, invalid commands, terminal locks, and deterministic replay/tamper rejection. Existing core tests remain the compatibility check for non-Battle gameplay.

## B2 CPU simulation

`battle_cpu.gd` is a pure scheduler/reducer using the existing `DeterministicRng`. Rules-2 initial state includes the seeded first deadline. `cpu_step` transactions record each solve or mistake at its exact integer-millisecond deadline, together with resulting RNG state, next deadline/type, burst count, behavior mode, streak, and workload. Wrong-side and off-deadline steps are rejected. Rules-1 definitions keep their original initial state and cannot run CPU steps.

`BattleCpuDriver.advance_to(active_time_ms)` is a polling adapter over that store, not a scene timer. The host supplies elapsed active-play time, excluding pauses. Calls before a deadline do nothing, and repeated calls cannot double count. Different frame sizes produce identical CPU event timelines, provided the same player-event ordering is supplied. Catch-up processes at most 128 events per call and returns `pending` when the caller must continue at the same horizon; it never silently skips overdue events. The prototype supports nonnegative active times up to 2,147,483,647 ms. It stops immediately on either winner. A later host must order player events against scheduled CPU events; this does not finalize the simultaneous-finish policy.

All CPU tuning is snapshotted under `cpu` in the JSON definition:

| Field | Default | Meaning |
| --- | --- | --- |
| `base_interval_ms` | 2500 | Normal interval between solve opportunities |
| `variance_ms` | 600 | Seeded plus/minus interval variation |
| `streak_chance_bp` | 1800 | Chance to begin a burst when none remains |
| `streak_pairs` | 3 | Burst duration in solved pairs |
| `streak_speed_bp` | 14500 | Burst speed; 10000 means normal speed |
| `pause_chance_bp` | 800 | Chance an opportunity becomes a mistake/pause |
| `pause_ms` | 1800 | Additional recovery time after a mistake |
| `recovery_rate_bp` | 10000 | Recovery speed; larger means shorter pauses |
| `difficulty_bp` | 10000 | Overall speed multiplier, applied to solves and recovery |

A mistake clears CPU streak and burst momentum, then schedules a guaranteed solve after recovery so even 100% pause chance can make progress. Each solve increments CPU streak. Burst speed is independent of player Combo: CPU `momentum_units` is provisionally 10000 while a faster burst is scheduled and zero otherwise. CPU score stays unchanged because B2 defines no scoring rule. Charge, attack efficiency, payloads, and cancellation remain B3/B4 work; the CPU cannot add tiles to the player's board yet.

Verification: `godot --headless --path . --script res://tests/battle_cpu_runner.gd`. Human-readable preview: `godot --headless --path . --script res://scripts/tools/simulate_battle_cpu.gd -- 42`. The preview simulates up to 600 active seconds and prints every second containing CPU events. This is debug observability, not the B8 HUD or a playable Battle launch path.

## B3 player attack charge

`battle_player_adapter.gd` consumes every committed Mahjong transaction in source-revision order from a fresh game. It clones the game definition, verifies source state hashes through the existing reducer, and advances its mirror only after Battle accepts the event. Duplicate or out-of-order delivery cannot award progress or charge. The initial Battle player workload must match the definition's tile count. No scene or animation callback authors these events, and Quick Play/Tower are unchanged.

Rules-3 `player_event` transactions synchronize player score, Combo, Momentum, and resolved-pair progress. Natural `pair_resolved` and `flipped_pair_resolved` results award charge. Other pair removals advance progress but do not independently award charge. Layer completion means no unresolved tiles remain on that authored layer, including tiles held in the tray; each layer rewards at most once. Layer and Momentum bonuses accompany a natural match only. The Momentum high-water mark prevents dropping and regaining a tier from farming bonuses.

All provisional tuning is snapshotted under `charge`:

| Field | Default | Meaning |
| --- | --- | --- |
| `normal_pair_units` | 1000 | Charge per natural pair |
| `fast_pair_bonus_units` | 500 | Bonus for a consecutive fast pair |
| `fast_pair_window_ms` | 2000 | Inclusive active-time window since the previous natural pair; Combo must be at least two |
| `layer_clear_bonus_units` | 2000 | Bonus per newly completed layer |
| `momentum_bonus_units` | 1000 | One-time major Momentum threshold bonus |
| `momentum_bonus_tier` | 4 | First rewarded tier |
| `attack_threshold_units` | 4000 | Charge consumed per outgoing attack pair |

Every threshold crossing appends an attack to the opponent's incoming `pending_attacks` queue, recording source, target, source-derived ID, creation time, and pair count. A large award can send multiple pairs in one attack; integer remainder charge is preserved. The normalized charge helper is available for the future HUD. Under rules 3, pending attacks do not travel or cancel. Rules 4 adds the queue lifecycle below; physical tiles and workload effects remain deferred. First-clear-wins still applies even with pending attacks; changing completion eligibility needs an explicit later decision.

A streak break or non-natural pair removal resets fast-match cadence. Ordinary nonmatching selections preserve it while Combo survives. The current source transactions do not distinguish manual taps from ordinary automatic Three Pair Clear/endgame taps; those count as natural events in this prototype. Production automation eligibility, hearts/defeat, and simultaneous CPU/player ordering remain open before playable integration. These defaults are tuning candidates, not final balance decisions.

Validate B3 with `godot --headless --path . --script res://tests/battle_charge_runner.gd`. Coverage includes threshold overflow, multi-pair attacks, bonus eligibility, replay/tamper rejection, malformed events, terminal state, and an entire real Mahjong game consumed exactly once.

## B4 attack queue and cancellation

Battle rules 4 snapshots `attacks.delay_ms` (default 1000; supported 1-60000 active milliseconds). Earlier rules retain their original snapshots and behavior. Each pending attack carries a stable sequence/ID, source, target, complete-pair count, creation time, and landing deadline. Rules 5 adds pair identities as described below.

`send_attack` takes `side`, positive `pair_count`, and `at_ms`, using the standard command ID/revision envelope. This is a simulation input for either side; it does not itself generate CPU charge. Player charge crossings automatically call the same reducer. Sending consumes the oldest incoming pairs first, spans queue entries when needed, and sends only excess pairs. Partial cancellation preserves the remaining attack's original deadline. Charge remainder is untouched. `BattleAttacks.pending_pairs` exposes the current incoming count for each side.

`advance_attacks` takes `side` and `at_ms`; it advances the entire queue clock, regardless of the envelope side. The future host supplies active-play time, excluding pauses. Player events, CPU steps, and explicit sends also advance this clock atomically before their action. Backdated commands are rejected. Hosts must interleave CPU deadlines and player events chronologically before advancing an idle queue clock; the CPU-only driver is not a combined Battle scheduler.

The provisional boundary rule is that attacks due at or before an action timestamp land before that action can cancel them. Equal-deadline attacks land in send-sequence order. Coarse clock updates retain exact landing timestamps. This fixes the cancellation boundary for rules 4, while simultaneous CPU/player victory priority remains a host-integration decision. Generic untimed B1 workload/stat commands remain debug primitives and must not replace timed gameplay input in a host.

Landing removes the incoming entry and appends it to `landed_attacks`, an inspectable handoff record. It does not yet insert player tiles or increase CPU workload: those are B6 and B7. Landed attacks cannot be cancelled or land twice. Rules 6 consumes player-targeted landings when a player board is bound; rules 7 consumes CPU-targeted landings as workload. `resolving_attack` remains unused because no board insertion takes place. A winner still freezes all commands, including queued attacks.

Rules-4 transactions also record deterministic `attack_sent`, `attack_cancelled`, and `attack_landed` events for future presentation. Replaying recomputes and verifies these events together with state. Invalid commands roll back both deadline processing and cancellation. B4 has no visuals, sound, wall-clock timers, or gameplay-scene integration.

Validate with `godot --headless --path . --script res://tests/battle_attack_runner.gd`: symmetric partial/full/excess cancellation, FIFO across entries, exact warning boundaries, charge integration, atomic rejection, legacy compatibility, victory freeze, clock granularity, and replay/event tamper rejection.

## B5 matching tile payloads

Battle rules 5 adds `payload.faces` and `payload.max_pairs` to the snapshotted definition. The default pool uses the existing 24 `reference` identities, preserving the current board vocabulary and cosmetic mapping. Explicit alternative pools may use supported Bamboo/Dots/Characters 1-9, winds, or dragons; unsupported and duplicate identities are rejected. This does not finalize a production switch to the 34-face vocabulary or change any reference deal. Skins and artwork never participate in payload generation.

Each outgoing attack now contains `tile_pairs`. Each pair has a stable attack-derived ID and exactly two tiles, each with its own unique attack-derived physical ID plus `face_family` and `face_value`. Both members match using the existing TileFace equality rules. Coordinates, slots, modifiers, and face-down state are intentionally absent: insertion owns those decisions in B6.

A separate `payload_rng_state`, initialized from the Battle seed, uses the existing deterministic RNG without advancing the CPU scheduler stream. Each attack draws from its configured pool without replacement; a fresh bag is used only once all identities have been drawn. Thus an attack no larger than the pool contains no repeated pair identity, and larger attacks distribute identities evenly. Small and single-face pools remain valid. The pool resets per attack; this is not a cross-attack collection/deck mechanic.

Cancellation still happens first. Fully cancelled outgoing power consumes no payload RNG. Excess outgoing pairs receive payloads; cancellation removes complete pairs from the front of the incoming payload and includes those exact removed pairs in transaction events. Surviving pairs retain their original IDs, identities, order, and deadline. Landing records the same surviving payload without regenerating it. Replays verify payload, cancellation events, and RNG along with the state.

The default `payload.max_pairs` is 128 (supported 1-1024) to bound allocations per attack. The limit applies to outgoing excess after cancellation. An oversized remainder rejects the entire transaction atomically, including provisional cancellations and deadline processing; nothing is truncated or silently dropped. Production charge tuning and host error handling must respect this cap. Historical rules 1-4 retain their original states and count-only attacks.

Run `godot --headless --path . --script res://tests/battle_payload_runner.gd` for seed reproducibility, complete-pair validation, variety, pool validation, separate RNG, cancellation/landing preservation, replay tamper rejection, size-limit rollback, legacy behavior, and charge integration. Inspect an attack with `godot --headless --path . --script res://scripts/tools/inspect_battle_payload.gd -- 42`.

No physical board insertion, CPU workload delivery, Battle launch UI, or presentation is added by B5.

## B6 player board insertion

Rules 6 supports a bound simulation board. `bind_board` must be the first Battle command, use side `player`, and contain a typed `GameDefinition.to_dict()` snapshot as `game_definition`. Its initial tile count must match the Battle player workload. Binding validates geometry and a full transaction-verified route. This is an in-memory simulation API, not a permissive JSON importer. Original physical IDs beginning with `attack_` are reserved against attack-ID collisions.

The original definition is retained unchanged under `player_board.original_definition`. Battle stores a separate current definition and game-state snapshot, insertion RNG state, applied-attack IDs, and a certified route. Each insertion records the complete before/after board revision in the enclosing Battle transaction. This addresses the existing Mahjong engine's fixed-definition assumption without mutating a run's original definition or changing non-Battle state/replay formats. Original layout ID/revision/hash remain provenance; current geometry is carried by the explicit serialized slot positions and effective definition hash. The Battle timeline, rather than an isolated later Mahjong transaction, is the replay authority across these revisions.

`board_input` takes `side: player`, `action: select_tile` or `reveal_tile`, `tile_id`, and active `at_ms`. It uses the existing Mahjong command processor/reducer, records the resulting ordinary transaction, and updates race progress, charge, score, Combo, and Momentum atomically. Bound runs reject the old player-event observer and debug player progress/stat mutations to prevent double counting. Injected tiles match and resolve through the same rules as original tiles. This simulation API currently exposes taps/reveals; Battle consumable/Undo policy and automated command scheduling remain integration work. Existing Quick Play/Tower actions are unchanged. A normal board loss ends the bound Battle as a CPU win.

Due player-targeted attacks are processed before timed board input, CPU steps, sends, or explicit clock advances. Each attack inserts atomically and increments player remaining work by its surviving pair count only after validation succeeds. Consumed IDs prevent duplicate insertion. Rules 6 leaves CPU-targeted attacks as landed handoff records; rules 7 applies their workload. A previously committed winner freezes pending work, preserving the existing first-completion contract.

| Insertion field | Default | Meaning |
| --- | --- | --- |
| `top_chance_bp` | 8000 | Seeded per-tile preference for top placement, with the other method as a geometry fallback |
| `max_layer` | 8 | Highest allowed zero-based layer |
| `max_tiles` | 256 | Maximum unresolved board-plus-tray tiles after insertion |
| `attempts` | 24 | Candidate layouts attempted per attack |
| `solver_nodes` | 5000 | Geometry/identity search budget per candidate |

This initial placement schema anchors new tiles to existing active slot footprints. Top placement adds a supported tile one layer above an anchor. Under placement inserts at the anchor's layer and lifts its full overlapping upper closure by one layer, including staggered overlaps. Original slot IDs and all physical tile IDs remain stable; only the affected slots' heights change. Tiles already resolved or held in the tray retain their state and slots. New attack slots use their unique physical IDs. Within an attack, unused columns are preferred whenever the current candidate set offers them. Matching members are placed independently, rather than forcing a pair to share one position.

No active same-layer footprints may overlap. New and lifted tiles must have immediate overlapping support; preexisting unsupported geometry is retained, since ordinary Mahjong removal and the reference layout can leave vertical gaps. Coordinates remain portrait-authored and orientation-independent. This is a conservative existing-footprint placement schema, not a search over every possible half-grid offset or an expansion of the board's horizontal bounds.

Every candidate receives a bounded pair-removal/held-mate search followed by the existing solver's full ordinary-transaction verification. Flipped tiles, modifiers, tray occupancy, and normal rule behavior participate in that final verification. Uncertified candidates are discarded. The planner may conservatively miss routes requiring temporary unmatched moves; exhausting its search budget records `attack_insertion_deferred`, retains the payload, and retries on subsequent timed commands. It does not mean the position is impossible and never causes defeat by itself.

Exceeding the unresolved-tile cap or finding no supported top/under position in the implemented anchor schema commits `board_overflow` and a CPU win. No part of that attack is inserted; earlier successfully inserted attacks remain. An insertion event includes placements, shifted slot IDs, pair count, and a certified route. Presentation can consume these later; no Battle screen or insertion animation is introduced by B6.

Run `godot --headless --path . --script res://tests/battle_insertion_runner.gd` for both placement types, pair spreading, stable IDs, held-tray/multi-pair handling, staggered closure lifting, race setbacks, duplicate/tampered replay rejection, normal play through the enlarged board, overflow, budget deferral, and all placement mixes on the 96-tile reference board. Inspect a reference-board insertion with `godot --headless --path . --script res://scripts/tools/inspect_battle_insertion.gd -- 42`.

## B7 CPU pressure

Battle rules 7 applies each CPU-targeted landed attack exactly once, tracked by `cpu_applied_attacks`. Its surviving pair count is added directly to CPU `remaining_pairs`; completed pairs are preserved. The resulting increased denominator moves existing CPU race progress backward. Cancellation continues to remove pairs before landing, so cancelled pairs never add work. Player-targeted payloads remain owned by B6 insertion.

Pressure is applied after due attacks land and before the current timed action. This includes CPU steps, player events, board input, sends, and queue-clock advances. At an exact tie, a due attack adds its work before the CPU's potential finishing solve. Previously committed winners still freeze all commands. The provisional relative ordering of simultaneous player and CPU inputs remains a host responsibility.

Delivery does not modify CPU RNG, solve deadline, streak, Momentum, difficulty, or recovery cadence. The CPU continues solving the enlarged workload under its existing scheduler and can still win. There is no added stun or speed penalty. `cpu_pressure_applied` events record the attack ID, original landing timestamp, pair count, and remaining work before/after for future presentation. Work exceeding the existing integer counter limit rejects the entire command atomically, including provisional landings. Rules 1-6 retain their original replay behavior.

Validate with `godot --headless --path . --script res://tests/battle_pressure_runner.gd`: delay, race setback, schedule preservation, cancellation, exactly-once application, recovery to victory, same-time completion, terminal freeze, historical rules, overflow rollback, and replay/tamper rejection. This completes workload delivery; CPU attack generation still uses the explicit symmetric send input from B4. Automatic CPU charge/attack-efficiency tuning and the combined playable host remain integration work. B8 adds the Battle HUD; this milestone adds no scene or animation.

## B8 playable host and HUD

Game Hall now opens `BattleShell` from Town. It uses the existing BoardView, TrayView, tile skin, and gameplay background resource. Portrait and landscape recompose one component tree; safe-area recipes reserve separate HUD, tray, board, and pause regions. The theme resource provides replaceable Battle panel, player, CPU, and text colors alongside its existing fonts and artwork. Live race fills move toward the central finish, while a separate circular attack dial displays charge. Score, streak, CPU remaining pairs, and incoming pairs are live values. Incoming warnings include deferred, not-yet-inserted landings and change to the CPU warning color.

`BattleHost` binds a reference board and merges CPU deadlines, attack deadlines, and taps on an integer active-play clock. It processes due events chronologically, with the CPU first on exact player/CPU input ties; existing store rules land due attacks before that input. This is the initial playable tie policy. Idle polling creates no transactions, so polling frequency does not change the authoritative timeline. Catch-up is capped at 128 events per call with explicit `pending`. Pauses and simulation-worker processing time do not advance the presentation-owned active clock.

Rules 8 snapshots `cpu_attack_charge_units` (default 1000, supported 0-1000000) and uses the shared attack threshold (default 4000). Each non-final CPU solve awards charge; pauses award none. Threshold crossings invoke the same cancellation and payload generation as player attacks, preserving remainder charge. A finishing solve wins without sending a post-victory attack. These are provisional balance values; unusually large charge/low threshold combinations must respect the existing payload cap. Earlier rules retain manual CPU sends and their original replay behavior.

The UI runs simulation calls on one worker at a time and presents only completed snapshots on the main thread. Insertion certification never blocks drawing or native controls. The board ignores new taps while a simulation command is in progress; there is no animation callback authoring game state. Geometry changes rebuild shared board/tray views from the effective definition; ordinary moves refresh their state. Locked-tile taps now route through the normal Combo-break transaction in rules 8. The initial Battle screen exposes taps/reveals, Pause/Resume, New Battle, and Town. Battle consumables, loadout selection, and automated endgame/Three Pair Clear scheduling are not enabled in this first host.

Pause and results extend the shared GameOverlay template. App focus loss pauses, resets board presses, and requires explicit Resume. Resume excludes paused time, New Battle uses a fresh seed, and Town returns through AppRoot. Worker shutdown joins outstanding simulation before freeing the screen. Terminal player/CPU wins freeze further input. Host failures show a retry/town overlay rather than continuing a desynchronized game.

This is a playable prototype: board changes are shown directly, without B9 attack travel, collision, or insertion animation/sound. CPU identity is the neutral `CPU` label until character work. No persistence, progression, or backend is added.

Validation: `tests/battle_host_runner.gd` verifies clock granularity, input ties, automatic CPU charge, real insertion, and completion; `tests/battle_ui_runner.gd` checks loading, pause, and non-overlapping safe-area regions at 390x844, 844x390, and 320x568. Running the latter without `--headless` also saves portrait/landscape previews under ignored `build/`. Town and existing gameplay tests remain regression coverage.

The playable host supplies the generator's certified route at binding; the ordinary transaction verifier checks it before acceptance. This avoids repeating a bounded search for a board already certified by generation. Insertion search indexes geometry blockers once per candidate, preserving route order while avoiding repeated footprint comparisons at each search node. The UI smoke test also advances a live CPU attack, verifies new tile controls, checks focus-loss pause, and starts a fresh battle.

## B9 attack feedback

BattleShell now consumes committed host events through a presentation-only BattleAttackFx layer. Counted pair markers travel from the charged player dial toward the CPU, or from the CPU toward the Board, using the same active-play timestamps as the pending attack. Partial cancellation removes the exact leading payload pairs, updates the surviving count, and collides opposing colored markers; full cancellation removes the packet. CPU workload application pulses its race endpoint. Successful insertion highlights the actual inserted physical tiles and adds a brief downward ceramic echo. Deferred insertion and overflow have explicit callouts. One Board callout lane avoids obscuring live HUD values.

All workload, insertion, victory, and progress updates remain immediate committed snapshots; FX never postpone or author gameplay. Markers represent pair counts rather than final face-art payload sprites. Catch-up batches are condensed to the latest cue per region, with a bounded transient budget. Pause freezes the cues and silences audio, while New Battle clears them. Positions are resolved from current HUD and Board geometry on drawing, including after rotation. Quiet existing swoosh and collision assets serve as replaceable sound hooks; volume, enablement, and cue duration are presentation properties. Final character reactions and audiovisual polish remain outside this slice.

The host also preserves already-committed deadline events when a later tap is rejected or arrives after a win, delivering those events once. Validate with `tests/battle_fx_runner.gd`, `tests/battle_host_runner.gd`, and `tests/battle_ui_runner.gd` (the latter renders orientation screenshots without `--headless`).

## B10 character reactions

`BattleHost` projects read-only `character_reaction` events from each committed transaction, including catch-up deadlines and rejected-tap delivery. Opening events are exposed separately as `opening_events`. Hooks cover start, ordinary CPU attacks, big attacks, cancelled attack ownership, applied hard hits, threshold crossings for streak/near-win, overtaking comebacks, and wins. Thresholds live in `configuration/battle/reaction_cues.json`; they do not enter authoritative game state, RNG, or replay hashes. A comeback currently means moving directly from behind to ahead in workload progress. These are derived host observations, not additional gameplay transactions or a new rules version.

Rivet is the first implemented opponent from the user's supplied character storyboard. `GameplayTheme.battle_character` resolves a separate character resource, with a default Rivet resource and per-expression fallback. Confident and frustrated transparent sprites derive from the supplied reference; asset provenance and exact generation prompts live in `art-source/characters/rivet/README.md`. Personality text, priorities, durations, and cooldowns belong to `BattleCharacter`, not the simulation. No character-specific powers, roster picker, or persistent ownership is introduced.

The persistent Battle HUD is a compact horizontal header above the playfield in both orientations, reduced from 128 to 88 reference pixels. Symmetrical progress tracks have explicit markers moving inward toward FINISH. The midpoint dial contains only charge percentage, with FINISH above and ATTACK below. Score and emphasized streak occupy the player side; CPU workload and incoming counts occupy the opponent side. Shared HUD anchor methods locate attack travel and impact feedback at the live race markers. Uneven ink borders, paper colors, and existing lettering preserve the collage language. Pause is a separate small square in the upper-right safe area. Portrait stacks the tray and Board closely below the header; landscape places the tray below its left end to preserve the Board's vertical footprint. Board geometry, topology, tile rules, and BoardView implementation are unchanged.

Character dialogue reserves no permanent layout space. Rivet slides in from the upper-right as a large cropped bust attached to an angular speech bubble, briefly overlapping the HUD. The shared overlay is clipped to the header band to keep Pause, live tray tiles, and Board clear; idle rendering is empty. Reaction appearance and expiry never move the underlying components. Rivet remains the CPU speaker even when commenting on a player event. No player-character reaction is currently shown; a future player cut-in must originate from the lower-left. Artwork uses mipmapped linear filtering and 512-pixel runtime imports. Result overlays display the matching portrait and win/loss line without delaying the committed winner.

The default reaction lasts 1.35 seconds with a 7-second cooldown. Higher priorities may interrupt; equal/lower priority cues are dropped during cooldown, rather than queued for stale playback. A batch chooses its highest-priority cue (latest on ties), and revision tracking prevents duplicate delivery. Pause freezes reactions, Restart clears timing and revision history, and reaction presentation never pauses gameplay or drives a command. Wins override ordinary cooldowns. Only two expressions and a short line per cue are included; further personality art remains future content.

Validation: `tests/battle_reactions_runner.gd` covers semantic projection and non-mutation; `tests/battle_character_runner.gd` covers priority, cooldown, alpha, pause, expiry, duplicates, restart, and expression fallback. `tests/battle_hud_runner.gd` verifies race symmetry and charge/progress separation. `tests/battle_ui_runner.gd` checks stable layout during cut-ins, protected gameplay regions, and result-panel safe bounds at portrait, landscape, and small-phone sizes. Existing host, attack FX, and Town Hub regression runners also pass.
