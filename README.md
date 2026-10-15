# Arcane Legacy — 2D Top-down Gameplay Prototype

An **asset-free Godot 4.x GDScript prototype** for testing three connected ideas:

1. Death persists on **one immutable generated character**: banked gold and discoveries survive; wounds and equipment wear are applied; carried gold drops as a recoverable corpse with 30% lost.
2. Two different dungeon layouts: **fixed ruins** reuse their original map seed and corpse position; **shifting maze** gets a new seed and relocates recoverable belongings.
3. Movement-independent **rune-casting** and swordmaster-inspired **relative time dilation**: player remains normal speed while enemies and enemy projectiles run at 35% speed.

## Play
1. Download and extract the project folder.
2. Install Godot 4.4+ from https://godotengine.org/download (4.6 recommended, subject to compatibility).
3. In the Godot Project Manager click **Import**, select `project.godot`.
4. Run using **F6/F5** or the Play button (F5 is conventional for project run).

## Inputs
| State | Input | Effect |
|---|---|---|
| Hub | 1 | Enter fixed-layout ruins |
| Hub | 2 | Enter reshuffling flux maze |
| Hub | H | Pay gold to cure accumulated injuries |
| Dungeon | WASD | Move freely |
| Dungeon | Mouse aim + left click | Sword swing |
| Dungeon | Hold SHIFT | Slow enemy movement / projectiles but not the player; consumes focus |
| Dungeon | Hold right mouse, Q/E/R in sequence, then left click | Explore and cast rune recipes |
| Dungeon | Right mouse release | Cancel rune sequence |
| Dungeon | F near orange marker | Recover the previous corpse's gold |
| Dungeon | F near gold gate | Return to hub; deposit expedition gold |

**Spoiler - test recipes** (leave these OUT of the eventual live game's guide):
- `Q E` -> Ember: fiery ranged projectile.
- `E Q` -> Mend: restore HP.
- `R R` -> Pulse: short-range AoE attack.

## Limits / engineering to address next
- This is a **prototype**, not a released game. It uses circles/rectangles instead of sprites; no audio, animation, menus, inventory, true room-graph or enemy AI pathfinding.
- Unstable layouts currently randomize block placement inside one arena rather than producing a fully procedural multi-room labyrinth.
- A future version should store dead-drop gear item IDs, stability/expiry rules, dungeon floor IDs and corpse ownership. Only currency is modeled here.
- Real save-file protection cannot be guaranteed for offline single-player. The character is retained unless players modify/delete local save data.
- Rune commands are currently shared across characters, vulnerable to online recipe sharing. A future research system could individualize rune-symbol mappings per character and offer in-game clues, while preserving discoverability and accessibility.
- Damage and time slow are **per actor** with manual scaled deltas. Global `Engine.time_scale` is deliberately NOT used, to avoid slowing the player and future multiplayer complications.
- No Godot binary was available in the authoring environment, so this zip was **not verified by a Godot runtime**. Open in Godot and let Codex fix any import/parser or input issues as its first task. Visual/playtest tuning has not been completed.

## Recommended Codex next task
1. Open the imported project in Codex IDE, desktop, or CLI.
2. Run/import the Godot project and fix parse/runtime problems (if any).
3. Refactor the monolithic `scripts/main.gd` into `Player`, `Enemy`, `DungeonManager`, `RuneSystem`, `TimePerception`, `DeathRecovery`, `SaveManager` components.
4. Add a tiny Godot headless smoke test for first boot, input transitions, resurrection, persisted fixed-dungeon seeds, and variable dungeon seed changes.
5. Replace the arena with 5-8 connected procedural rooms while guaranteeing reachable loot and an exit.
