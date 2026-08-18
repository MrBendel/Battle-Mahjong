# Game Vision

Battle Mahjong is a fast-paced mahjong solitaire game focused on flow, look-ahead, momentum, tray risk management, RPG-style modifiers, consumables, cosmetics, and asynchronous competition.

Core principle:

> Battle Mahjong is a game about staying in motion.

## Player Skill

The core skill is not merely recognizing matching mahjong tiles. It is recognizing the next match while resolving the current one.

The game should reward:

- speed
- consistency
- look-ahead
- board recognition
- intelligent risk-taking
- recovery from mistakes

The game should discourage:

- repeatedly stopping to stare at the board
- slow, consequence-free searching
- passive play

## Experience Goals

- The board should remain readable under pressure.
- Fast look-ahead play should feel meaningfully different from slow searching.
- The game should recognize strong player behavior with contextual praise.
- The better the player is doing, the more excited the presentation becomes.

## Game Modes

### Daily Play

Includes:

- Daily Challenge
- Tournaments
- Tower / Endless

Daily Challenge can use a deterministic seed shared by all players.

Tower / Endless is expected to become a major progression and RPG-oriented mode.

### Battle

Asynchronous PvP where players compete against recorded performances on the same deterministic board/configuration.

The opponent may appear as a progress ghost rather than a live player.

Battle should focus on competitive execution rather than direct attacks or garbage mechanics.

Rating should use an Elo-style or related chess-inspired model.

Status: Open Question

- Exact rating model: Elo, Glicko, or derivative.
- How permanent RPG progression is separated from ranked competitive fairness.

### Practice

Unscored play.

Possible future practice options:

- unlimited Undo
- no momentum decay
- display available pairs
- choose specific modifiers
- instant restart
- custom board difficulty

## Recognition And Praise

Possible callouts:

- AMAZING!
- GREAT FIND!
- EAGLE EYES!
- THAT WAS HIDDEN!
- SAW THAT COMING!
- ONE STEP AHEAD!
- CLUTCH!
- LIGHTNING!
- LOCKED IN!
- ICE COLD!
- UNSTOPPABLE!

Heuristics may include:

- spatial distance between matched tiles
- depth differences
- visual clutter
- visual ambiguity
- how recently a tile became exposed
- time between exposure and selection
- current tray danger
- available-pair scarcity
- match timing

A strong look-ahead signal is when a tile becomes newly playable and the player matches it almost immediately.

Status: Open Question

- Exact praise rules and thresholds.
- How to validate praise heuristics against player behavior.
