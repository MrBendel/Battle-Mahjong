# Battle Mahjong

Battle Mahjong is a fast-paced mahjong solitaire game about solving continuously and solving quickly.

Core principle:

> Battle Mahjong is a game about staying in motion.

The project is currently in documentation and scaffolding. Gameplay implementation, engine selection, networking, monetization, accounts, and backend systems are intentionally out of scope until their milestones.

## Source Of Truth

Read these documents before implementing:

- [docs/GAME_VISION.md](docs/GAME_VISION.md)
- [docs/CORE_GAMEPLAY.md](docs/CORE_GAMEPLAY.md)
- [docs/SYSTEMS.md](docs/SYSTEMS.md)
- [docs/ROADMAP.md](docs/ROADMAP.md)
- [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md)
- [docs/TECH_NOTES.md](docs/TECH_NOTES.md)

## Current Status

- Engine choice: Godot 4.6.3 stable.
- Primary language: GDScript.
- First implementation milestone: M0 Project Skeleton.
- Simulation and presentation should remain separate.
- All gameplay randomness must eventually use seeded deterministic RNG.
