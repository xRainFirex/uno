# DOS: An Uno Roguelike

A deck-building roguelike card game with shedding-style rules (match colour or number, empty your hand to win), made in **Godot 4.5**. Every card, icon, portrait and sound effect is generated in code. The only bundled assets are two open-licensed pixel fonts.

## Art style

The cards are an original pixel-art design rather than an imitation of any commercial card game:
- **Four elemental suits** fill the four colour slots: **Ember** (orange-red, flame), **Tide** (azure, wave), **Moss** (green, leaf) and **Dusk** (violet, moon). Each has its own corner emblem.
- **Cards are drawn at 26×38 pixels and shown at 5×.** Each has a two-tone bevelled frame, an octagonal crest plate, chunky bitmap numerals and pixel icons for every action.
- **Wild cards** have a banded four-element body with a gem crest.
- **The card back** is a gold lattice with the game's own sigil.

Everything is generated in code: `PixelCanvas` is a tiny rasteriser, `PixelCard` draws the cards, and `Glyph` draws the icons. The UI uses two open-licensed pixel fonts, **Silkscreen** (headings) and **Jersey 10** (body text), both under the SIL Open Font License (see `assets/fonts/`).

## Running

Open `project.godot` in Godot 4.5 or newer and press **F5**. The project uses the *GL Compatibility* renderer so it runs on almost any GPU and can be exported to the web.

## How a run works

- **Starting decks.** Choose a deck before each run. Winning a run with a deck unlocks the next one: Classic → Standard → Monochrome → Two-Tone → Trickster → High Roller. Each deck has its own cards and a perk, such as extra HP, a starting charm or extra gold.

- **Map.** Each of the three acts is a 13-floor branching map that scrolls, with the boss at the top. Most floors are battles, events and elites (red skulls, tougher opponents that drop a charm). Floor 9 is mostly elites. Specials are rare and spaced out, so on any route you'll find at most 2 shops, at most 2 rest sites (one is always the campfire before the boss) and exactly 1 treasure, and never two in a row.
- **Battles.** Each battle is a one-on-one card duel. Match the top card by colour, number or symbol. You draw from **your own deck**, which you grow and refine over the run, and the opponent draws from theirs.
- **Losing hurts.** If the opponent empties their hand first, you take damage for each card left in your hand and must replay the same battle. You can't move on until you win. At 0 HP the run is over.
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

- **Trick cards** (beyond the basic number and action cards):

  | Card | Effect |
  | --- | --- |
  | Discard All | Also discards every other card of its colour from your hand. |
  | Wild Swap | Choose a colour, then trade hands with the opponent. |
  | Dual-colour numbers | Count as both colours. You pick which one continues. |
  | Double Down (x2) | The opponent draws as many cards as they hold (max 6). |
  | Freeze | You take two extra turns. |
  | Gift | Give 2 random cards from your hand to the opponent (you always keep at least 1). |
  | Wild Chain | Choose a colour, then play again. |
  | Wild Mirror | Copies the effect of the card it covers. |

  From Act I, elites and bosses carry some trick cards (except Wild Swap and Discard All), and from Act II regular opponents do too. The count grows each act.
- **Bust:** anyone holding 25 cards loses the battle immediately.
- **Time limit:** if a battle reaches 200 turns, the smaller hand wins. This stops rare stalemates where both sides keep feeding each other draw cards. A warning appears 20 turns before the limit.
- **Enchantments:** *Gilded* (+3 gold when played), *Barbed* (opponent draws 1) and *Healing* (+2 HP). You get these at campfires, from events, and sometimes on reward cards.
- **23 charms:** passive powers such as *Prism*, *Seer's Eye*, *Spyglass*, *Phoenix Feather* and *Megaphone*. Eight of them build around trick cards:

  | Charm | Effect |
  | --- | --- |
  | Harlequin Mask | Your dual-colour cards can be played on anything. |
  | High Roller | Your Double Down has no cap. Push them past 25 cards to Bust them. |
  | Permafrost | Freeze gives 3 extra turns instead of 2. |
  | Wrapping Paper | Gift gives away 1 more card and earns 3 gold per card gifted. |
  | Clockwork | Heal 1 HP at the start of every extra turn. |
  | Funhouse Mirror | Your Wild Mirror also makes the opponent draw 2. |
  | Joker's Grin | Start every battle with a free random trick card. |
  | Trickster's Pact | Trick cards appear far more often in rewards, shops and events. |
- **29 opponents** in three acts, each with an AI style ("random", "aggressive" or "smart"). Elites and bosses have rule-bending abilities: *Spiky*, *Lockdown*, *House Tax*, *Chroma Shift*, *Quick Start* and *Thorns*. Trick-themed opponents build their decks around trick cards, some with abilities that mirror the trick charms (*Frostbite*: 3-turn Freeze, *Jackpot*: uncapped Double Down, *Generous*: their Gift gives you 3 cards):

  | Opponent | Act | Theme |
  | --- | --- | --- |
  | Pip | I | Small mixed bag of tricks |
  | Patchwork Pete (elite) | I | Dual-colour cards |
  | Frost | II | Freeze, with Frostbite |
  | Kringle | II | Gift, with Generous |
  | Gambler Gus (elite) | II | Double Down, with Jackpot |
  | Clockwork Clara | III | Freeze and Wild Chain |
  | The Ringmaster (elite) | III | Every trick card, with Jackpot and Generous |
  | The Jester King (boss) | III | Alternate final boss: every trick card, with Frostbite and Jackpot |
- **12 events**, half of them built around trick cards (the Two-Tone Painter, the Frozen Lake, Secret Santa, the Double-or-Nothing Table, the Clockmaker and the Jester's Game). There is also a shop with card removal, and campfires that offer rest or an enchantment.
- Lifetime stats and settings (sound on/off, fast mode) are saved to `user://dos_meta.cfg`.

## Project layout

```
scenes/Main.tscn            root scene
scripts/autoload/           RunState (run + meta state), Sfx (synthesised sounds)
scripts/core/               rules and data: CardData, CardFactory, BattleState, EnemyAI, Enemies, Charms, MapGen
scripts/ui/                 UIKit (theme/palette), PixelCanvas, PixelCard, CardView, Glyph, CharmIcon, Avatar, Hud, DeckViewer
scripts/screens/            Main router and every screen (Title, Map, Battle, Reward, Shop, Rest, Event, End)
shaders/felt.gdshader       card-table background
tests/sim_battles.gd        headless rules test
```

`BattleState` is a pure rules engine with no UI code. To simulate hundreds of battles and check that no cards are lost and every battle ends, run:

```
godot --headless -s res://tests/sim_battles.gd
```
