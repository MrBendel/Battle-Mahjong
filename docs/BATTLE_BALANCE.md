# B11: first mechanical balance pass

Status: instrumented first pass implemented; human feel validation remains open.

The prototype attack delay changes from 1000 to 2000 active milliseconds. This gives cancellation more opportunity before delivery. CPU cadence, charge rewards, attack size, insertion probabilities, board topology, and victory rules remain unchanged. Definitions snapshot tuning, so existing recorded battles retain their original delay.

## Reproduce

Run from the repository root with Godot 4.6.3:

```powershell
godot-console --headless --path . --script res://scripts/tools/measure_battle_balance.gd -- res://configuration/battle/balance_scenarios.json res://build/battle-balance.json
godot-console --headless --path . --script res://tests/battle_balance_runner.gd
```

Create the ignored `build` directory first if absent. The report saves after every match and includes the base definition and variant overrides. The matrix uses seeds 7, 42, and 99, three fixed tap cadences, two delay variants, and a 300-second horizon. Both variants explicitly override delay, so the comparison survives the new default. Other future default changes constitute a new experiment.

The probe uses the actual bound 96-tile board, ordinary taps, the host's chronological CPU/attack scheduler, and certified routes after insertions. It has perfect information and no recognition delay or mistakes. Results are mechanical comparisons, not human skill ratings or estimated human win rates. Same-time CPU deadlines precede taps, matching the host contract.

## Measured on 2026-09-26

Each row aggregates three seeds. Cancellation and landing columns count pairs across all three matches; P/C means player/CPU. Cancellation is credited to the defender; landing is credited to the recipient.

| Delay | Tap cadence | Mean seconds | Player wins | Cancelled P/C | Landed P/C |
|---|---|---|---|---|---|
| 1 s | 800 ms | 83.7 | 3/3 | 5 / 8 | 13 / 48 |
| 2 s | 800 ms | 78.4 | 3/3 | 11 / 11 | 3 / 35 |
| 1 s | 1200 ms | 139.1 | 2/3 | 4 / 7 | 31 / 37 |
| 2 s | 1200 ms | 127.5 | 2/3 | 10 / 11 | 19 / 23 |
| 1 s | 1800 ms | 127.6 | 0/3 | 5 / 1 | 34 / 21 |
| 2 s | 1800 ms | 119.2 | 0/3 | 7 / 7 | 23 / 11 |

Player cancellations rose from 14 to 28 pairs. CPU cancellations rose from 16 to 29. Winners stayed the same for every seed/cadence combination. Less added work shortened matches for both winning and losing players: a longer window is not simply an easier CPU. The fastest player at seed 99 cancelled every incoming pair under the new delay; watch for overly quiet matches in human testing.

All 18 matches finished within the horizon without overflow or deferred insertion. Maximum occupied layer index was 6 with the old delay and 4 with the new delay. Both top and under placements occurred. These three seeds do not establish safety across every generated layout or prove that under insertion feels fair.

The report also records first attack time, placement counts, peak unresolved tiles, and player pairs cleared after the first hit. The latter conservatively excludes a pair cleared on the exact landing tick, if any; it measures continued progress, not subjective recovery.

## Tuning ownership

`BattleShell.battle_tuning_path` selects a full JSON definition for local playtests. Invalid definitions fail before generation. Store snapshots prevent changes during a match.

| Concern | Existing tuning / policy |
|---|---|
| Starting workload | `player_starting_pairs`, `cpu_starting_pairs`; player count must match the bound board |
| CPU pace and personality | `cpu.base_interval_ms`, variance, difficulty, streak and pause fields |
| Attack charge | `charge` normal/fast-pair, layer and Momentum bonuses; threshold; `cpu_attack_charge_units` |
| Response window | `attacks.delay_ms` |
| Placement and safety | `insertion.top_chance_bp`, maximum layer/tiles, attempts and solver budget |
| Travel and reactions | Presentation-only `BattleAttackFx.cue_seconds`; character duration, cooldown and entrance exports |
| Progress and victory | Existing inward race and first-to-zero workload policy; no alternate win condition introduced |
| Cancellation | Existing symmetric one-for-one cancellation; no new ratio or mechanic |

Fast pairs already connect pace to attack charge. This pass does not invent a separate streak multiplier. Presentation timing never changes authoritative deadlines.

## Human playtest still required

Play portrait and landscape, including a small phone, and record seed and tuning file:

- Can a new player explain who is approaching the common finish and what fills the attack ring?
- Can they notice incoming pressure and intentionally cancel it? Does aggression versus defence feel like a choice?
- Are landed attacks meaningful, and does under insertion feel fair rather than confusing?
- Is recovery achievable without attacks becoming ineffective or overwhelming?
- Does Rivet feel active, and do fast pairs visibly connect to attacks?
- Is match length satisfying, including losing matches? Do reactions remain brief and leave controls usable?

Use those observations before changing CPU speed or adding mechanics. B11 is not a claim of completed human balance validation.
