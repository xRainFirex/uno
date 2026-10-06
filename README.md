# DOS: An Uno Roguelike

A deck-building roguelike played with UNO-style rules, made in **Godot 4.5**. Every card, icon, portrait and sound effect is generated in code, so the project has no art or audio assets.

## Running

Open `project.godot` in Godot 4.5 or newer and press **F5**. The project uses the *GL Compatibility* renderer so it runs on almost any GPU and can be exported to the web.

## How a run works

- **Map.** Each of the three acts is a branching map. Every row offers a choice of battles, elites, events, shops, campfires and treasure, with a boss at the top.
- **Battles.** Each battle is a one-on-one card duel. Match the top card by colour, number or symbol. You draw from **your own deck**, which you grow and refine over the run, and the opponent draws from theirs.
- **Losing hurts.** If the opponent empties their hand first, you take damage for each card left in your hand. At 0 HP the run is over.
- **DOS!** With two cards left, press **DOS!** (or `D`) before playing, or you may get caught and draw 2. If the opponent forgets to call it, press **CATCH!** in time to make them draw 2.

### Controls

| Action | Mouse | Key |
| --- | --- | --- |
| Play a card | Click it | |
| Draw | Click your deck | `Space` |
| Call DOS! | DOS! button | `D` |
| Pass after drawing | PASS button | `Enter` |
| Catch the opponent | CATCH! button | `C` |
| Pause | MENU button | `Esc` |

## Content

- **New cards:** *Discard All* also discards every other card of its colour from your hand. *Wild Swap* trades hands with the opponent.
- **Enchantments:** *Gilded* (+3 gold when played), *Barbed* (opponent draws 1) and *Healing* (+2 HP). You get these at campfires, from events, and sometimes on reward cards.
- **15 charms:** passive powers such as *Prism*, *Seer's Eye*, *Spyglass*, *Phoenix Feather* and *Megaphone*.
- **20 opponents** in three acts, each with an AI style ("random", "aggressive" or "smart"). Elites and bosses have rule-bending abilities: *Spiky*, *Lockdown*, *House Tax*, *Chroma Shift*, *Quick Start* and *Thorns*.
- **6 events**, a shop with card removal, and campfires that offer rest or an enchantment.
- Lifetime stats and settings (sound on/off, fast mode) are saved to `user://dos_meta.cfg`.

## Project layout

```
scenes/Main.tscn            root scene
scripts/autoload/           RunState (run + meta state), Sfx (synthesised sounds)
scripts/core/               rules and data: CardData, CardFactory, BattleState, EnemyAI, Enemies, Charms, MapGen
scripts/ui/                 UIKit (theme/palette), CardView, Glyph, CharmIcon, Avatar, Hud, DeckViewer
scripts/screens/            Main router and every screen (Title, Map, Battle, Reward, Shop, Rest, Event, End)
shaders/felt.gdshader       card-table background
tests/sim_battles.gd        headless rules test
```

`BattleState` is a pure rules engine with no UI code. To simulate hundreds of battles and check that no cards are lost and every battle ends, run:

```
godot --headless -s res://tests/sim_battles.gd
```
