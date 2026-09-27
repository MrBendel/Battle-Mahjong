# Battle Mahjong — 1P vs CPU Battle Mode

## Goal

Build the first playable Battle mode for Battle Mahjong as a 1-player-vs-CPU simulation.

The player's normal Mahjong puzzle remains the primary gameplay surface. We do **not** render the CPU's Mahjong board.

Instead, Battle mode is represented by three interconnected systems:

1. **Race Progress** — Player and CPU race from opposite ends of a shared progress bar toward the center. Reaching the center means finishing the board and winning.
2. **Attack Charge** — Good play fills a central attack dial. When the dial fills, matched tile pairs are sent to the opponent.
3. **Board Pressure** — Incoming attack tiles are inserted into the opponent's board, adding work and therefore moving their race progress away from the center.

The initial implementation should prioritize clear game-state behavior over final presentation.

---

# Milestone 1 — Battle State Model

## Objective

Create the underlying Battle-mode state without changing normal gameplay behavior.

## Requirements

Add a Battle game state capable of tracking:

* player progress
* CPU progress
* player attack charge
* CPU attack charge
* player score
* player streak
* CPU streak / momentum state
* pending player attacks
* pending CPU attacks
* battle winner
* battle state:

  * playing
  * resolving attack
  * player won
  * CPU won

Battle state should be separate enough from the existing board logic that Practice/Daily modes do not need to know about it.

## Progress Model

Do not initially calculate progress from elapsed time.

Progress should represent:

> remaining work required to completely clear the current board.

The simplest initial version can use:

`progress = cleared_pairs / total_pairs`

Player begins at the left side of the race.

CPU begins at the right.

Both move toward `0.5`, the center finish point.

Conceptually:

`PLAYER >>>>>>>>>>> FINISH <<<<<<<<<<< CPU`

Incoming attack tiles increase the denominator / remaining work and therefore move a player's progress back away from the center.

## Acceptance Criteria

* Battle mode initializes with player and CPU progress at their starting positions.
* Clearing player pairs advances player progress.
* A simulated CPU can independently advance CPU progress.
* Progress can move backwards when additional tiles are added.
* First side to reach the finish state wins.
* Existing non-Battle modes behave exactly as before.

---

# Milestone 2 — CPU Simulation

## Objective

Create a fake opponent that produces believable Battle pressure without requiring a rendered or fully simulated Mahjong board.

For this milestone, the CPU does **not** need to play an actual generated board.

## CPU Parameters

Create tunable values such as:

* base solve interval
* solve interval variance
* streak probability
* streak duration
* mistake / pause probability
* attack efficiency
* recovery rate
* difficulty multiplier

The CPU should periodically simulate clearing a pair.

Example:

`cpu_pairs_remaining -= 1`

CPU solving advances its race progress.

CPU performance should fluctuate slightly rather than operating at a constant mechanical rate.

## Acceptance Criteria

* CPU visibly progresses toward the finish.
* CPU speed can be changed using a difficulty configuration.
* CPU occasionally solves faster/slower.
* CPU progression stops after the battle ends.
* CPU simulation is deterministic when given a fixed RNG seed if practical.

---

# Milestone 3 — Player Attack Charge

## Objective

Connect successful player gameplay to the central attack system.

Introduce a normalized attack charge:

`0.0 → 1.0`

The attack dial fills based on player actions.

## Initial Charge Rules

Start simple and make these values configuration-driven.

Example starting values:

* normal pair clear: +1 charge unit
* fast consecutive match: streak bonus
* full layer clear: large bonus
* major momentum event: bonus

For the initial prototype, define an attack threshold such as:

`4 charge units = 1 sent pair`

When the threshold is reached:

1. create an outgoing attack
2. reset or subtract the charge threshold
3. queue the attack against the CPU

Allow overflow.

Example:

Player reaches `5 / 4`.

Send one pair.

Remaining charge becomes `1 / 4`.

## Acceptance Criteria

* Matching pairs fills attack charge.
* Attack charge responds to streak bonuses.
* Layer clears can add a larger charge bonus.
* Filling the dial creates an outgoing attack.
* Charge overflow is preserved.
* Values are centralized in Battle configuration rather than scattered through gameplay code.

---

# Milestone 4 — Attack Queue and Cancellation

## Objective

Add pending attacks so attacks are readable and can interact before hitting the board.

An attack consists of one or more complete Mahjong pairs.

Example structure:

`BattleAttack`

* source
* target
* pair_count
* tile_pairs
* delay
* attack_type

## Pending Attacks

Attacks should not land instantly.

Give attacks a short configurable travel / warning period.

Example:

`attack_delay = 1.0 sec`

During this period they exist in the target's incoming queue.

## Attack Cancellation

Outgoing attacks cancel incoming attacks before sending additional pressure.

Example:

Player has:

`3 incoming pairs`

Player generates:

`2 outgoing pairs`

Result:

`1 incoming pair`

No outgoing attack reaches CPU.

If player instead generates four pairs:

`3` cancel incoming attacks.

`1` continues toward CPU.

Cancellation should operate on pair count.

## Acceptance Criteria

* Player and CPU have visible pending attack counts internally.
* Outgoing attacks cancel incoming attacks first.
* Remaining attacks continue toward the opponent.
* Attacks land after a configurable warning period.
* Cancellation works identically for player and CPU.

---

# Milestone 5 — Attack Tile Generation

## Objective

Generate real Mahjong pairs when an attack is sent.

Attacks should contain actual matching tile pairs rather than generic garbage tiles.

Example:

`Red Dragon + Red Dragon`

The two tiles belonging to a pair do **not** need to land together.

## Rules

* Every attack must preserve pair balance.
* Never send a single unmatched tile.
* Attack tile selection can initially be random from valid Mahjong tile types.
* Avoid excessive identical pairs in one attack unless explicitly desired.

Later we may derive the sent pair from tiles the attacker actually collected, but this is not required for the first playable prototype.

## Acceptance Criteria

* Every attack creates valid complete pairs.
* Attack payload can be inspected/debugged.
* Pair generation can be seeded.
* Payload survives until insertion into the opponent board.

---

# Milestone 6 — Player Board Attack Insertion

## Objective

Allow CPU attacks to insert new tiles into the player's existing Mahjong structure.

This is the most important mechanical milestone after the basic battle loop.

Incoming tiles should be inserted into valid positions rather than simply creating a flat garbage row.

Support two placement categories.

### Top Placement

Place an incoming tile in a valid supported position above existing board geometry.

### Under Placement

Insert the incoming tile beneath an existing tile/stack.

Tiles above the insertion point move upward one depth level.

Conceptually:

Before:

`B`
`A`
`C`

Insert X under A:

`B`
`A`
`X`
`C`

Exact implementation must respect the game's existing board coordinate/depth model.

## Initial Attack Distribution

Start with mostly top placement.

Example:

* 80% top
* 20% under

Make this configurable.

Later attack types can favor deeper insertion.

## Placement Constraints

Insertion should:

* use valid board coordinates
* maintain physical/support rules
* never delete existing tiles
* preserve complete pair counts
* avoid placing the two matching attack tiles in trivially identical positions
* prefer spreading attack tiles across the board
* avoid repeatedly targeting the same column/location when alternatives exist

The resulting board should remain solvable whenever practical.

If the existing board solver can cheaply validate the post-insertion state, use it.

If no valid insertion exists because the board has reached its maximum legal height/depth, treat that as an overflow/loss condition.

## Acceptance Criteria

* Incoming pairs become real tiles in the player's board.
* Tiles may be placed on top.
* Tiles may be inserted underneath existing stacks.
* Under-placement correctly shifts affected tiles.
* Board remains structurally valid.
* Pair counts remain balanced.
* Attacks can push player race progress backwards.
* Overflow can trigger defeat.

---

# Milestone 7 — CPU Pressure Model

## Objective

Make player attacks affect the simulated CPU even though no CPU board is rendered.

Maintain an abstract CPU workload.

Example:

`cpu_remaining_pairs`

When player sends three pairs:

`cpu_remaining_pairs += 3`

Therefore CPU race progress visibly moves away from the center.

The CPU continues clearing this larger workload at its simulated solve rate.

## Acceptance Criteria

* Player attacks immediately add work to CPU.
* CPU race progress moves backwards when attacked.
* CPU can recover by continuing to clear simulated pairs.
* Large attacks create meaningful setbacks.
* CPU can still win after recovering from attacks.

---

# Milestone 8 — Battle HUD Prototype

## Objective

Replace temporary debug values with the first real Battle HUD.

Do not redesign the player's board.

Battle mode should primarily replace/extend the existing top status region.

## Shared Race Bar

Create one horizontal race display.

Player starts on the left.

CPU starts on the right.

Center represents victory.

Concept:

`YOU ━━━━━━━▶ ◉ ◀━━━━━━━ CPU`

The bars should visually indicate how close each side is to completion.

Player attacks move CPU away from center.

CPU attacks move player away from center.

## Central Attack Dial

Place the player's attack charge indicator at or near the center finish point.

The dial should represent:

`0% → 100% attack charge`

When filled:

1. attack triggers
2. dial visually fires/resets
3. outgoing tile attack begins

Do not combine race progress and attack charge into the same visual encoding.

Race progress = horizontal position.

Attack charge = circular fill.

## Player Stats

Display:

* score
* streak

Streak should receive more immediate visual emphasis than score.

Example:

`12,450     🔥 ×8`

Score remains stable.

Streak becomes increasingly visually prominent as it grows.

## CPU Information

Display:

* CPU character/name
* CPU race progress
* optional CPU streak/momentum state
* incoming attack warning

Do not render the CPU Mahjong board.

## Acceptance Criteria

At a glance the player can understand:

* who is ahead
* how close the player is to winning
* how close the CPU is to winning
* how close the player is to launching an attack
* current player score
* current streak
* whether an attack is incoming

---

# Milestone 9 — Basic Attack Presentation

## Objective

Give attacks enough feedback to evaluate whether the Battle loop feels satisfying.

Do not add final polish yet.

## Player Attack

When an attack fires:

* central dial completes
* attack payload appears
* tiles move toward CPU side
* CPU progress reacts when attack lands

## CPU Attack

When CPU attacks:

* show short warning
* show incoming pair count
* tiles move downward toward player board
* attack insertion occurs
* player progress reacts

## Cancellation

When attacks cancel:

* visually collide/remove paired attack markers
* clearly communicate the reduced attack amount

Sound hooks should be exposed even if final sound assets are not ready.

## Acceptance Criteria

* Player can visually understand why CPU progress moved backwards.
* Player can visually understand why new tiles appeared on their board.
* Attack cancellation is readable.
* No important Battle event occurs invisibly.

---

# Milestone 10 — Character Reaction Hooks

## Objective

Introduce the event system required for opponent personalities.

Do not initially build a large dialogue library.

Create events such as:

* battle_started
* player_big_attack
* CPU_big_attack
* player_long_streak
* CPU_long_streak
* player_near_win
* CPU_near_win
* player_attack_cancelled
* CPU_attack_cancelled
* CPU_hit_hard
* player_hit_hard
* CPU_comeback
* player_comeback
* CPU_win
* player_win

A Battle character definition should be able to associate short reactions with these events.

Example:

`CPU_hit_hard`

* "HEY! THAT'S NOT FAIR!"
* "OH COME ON!"
* "SERIOUSLY?"

`CPU_big_attack`

* "TAKE THIS!"
* "GOOD LUCK!"

## Reaction Presentation

Opponent normally occupies a compact HUD position.

During an eligible reaction:

* character portrait/art expands into the screen from the opponent side
* short text appears
* reaction disappears automatically
* gameplay should not pause

Use cooldowns so reactions remain special rather than constant.

## Acceptance Criteria

* Battle logic emits semantic reaction events.
* CPU character data can define reactions separately from Battle mechanics.
* Character reaction can appear without pausing gameplay.
* Reactions have cooldown / priority handling.
* Important gameplay events cannot be obscured by character UI.

---

# Milestone 11 — First Playable Balance Pass

## Objective

Evaluate the core Battle loop before building more content.

Expose tuning values for:

### Race

* starting pair count
* progress calculation
* win condition

### CPU

* solve speed
* solve variance
* streak behavior

### Attacks

* charge per match
* streak multiplier
* layer-clear bonus
* attack threshold
* attack delay
* top vs under insertion probability
* cancellation behavior
* maximum insertion depth

### Presentation

* attack travel speed
* reaction timing
* HUD animation speeds

## Test Questions

The prototype should answer:

1. Is racing toward a common center easy to understand?
2. Does filling the attack dial feel rewarding?
3. Do attacks create meaningful setbacks without feeling arbitrary?
4. Does cancellation encourage aggressive play?
5. Is under-insertion exciting or frustrating?
6. Are attacks frequent enough?
7. Can a player recover after being hit?
8. Does the CPU feel alive without displaying its board?
9. Does streak feel meaningfully connected to Battle performance?
10. Is the match length appropriate?

Do not add additional Battle mechanics until these questions have been evaluated.

---

# Suggested Development Order

Implement in this sequence:

**Phase A — Loop**

Milestones 1–3

Result:

Player and simulated CPU race toward the center, and player actions fill an attack meter.

**Phase B — Combat**

Milestones 4–7

Result:

Player and CPU can exchange real tile-pair attacks, cancel attacks, and push one another backwards.

This is the first milestone where Battle should be genuinely playable.

**Phase C — UI**

Milestones 8–9

Result:

The match becomes readable without debug information and begins to feel like Battle Mahjong.

**Phase D — Personality**

Milestone 10

Result:

Opponent characters begin reacting to actual Battle events.

**Phase E — Balance**

Milestone 11

Result:

Tune the system before introducing additional attacks, powers, characters, or Battle modes.

---

# Explicitly Out of Scope for V1

Do not implement yet:

* multiplayer/network play
* visible CPU Mahjong board
* sophisticated CPU puzzle solving
* character-specific powers
* special attack classes
* status effects
* blockers
* items unique to Battle mode
* ranking / matchmaking
* Battle campaign structure
* elaborate character animation
* multiple-round matches
* comeback modifiers
* final sound/VFX polish

Those should only be considered after the core attack/race loop proves fun.

---

# Architectural Principle

Battle logic should react to gameplay events rather than being embedded directly in tile interaction code.

Prefer a flow like:

`Board gameplay event`
→ `BattleController`
→ `update streak / score / progress / charge`
→ `BattleAttackController`
→ `attack queue / cancellation / insertion`
→ `Battle HUD + presentation events`

This should make the existing Mahjong board remain reusable across Daily, Practice, and Battle modes while allowing Battle rules to evolve independently.
