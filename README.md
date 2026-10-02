# Allemano Arcade

Small games for WoW Forever, in the Allemano look. The first game is **Hangman**: guess the WoW word one letter at a time, before the attempts run out. Play with a random word from a category (raid bosses, dungeons, zones, classes, races and factions, professions, items, lore), or let a friend type a word for you on the same computer.

Part of [Allemano Addons](https://allemano-site.pages.dev). Alpha: Hangman for one player or two on one computer. Connect Four, Rock Paper Scissors and Battleships are planned, and so is Hangman for a raid.

## Use

- `/arcade` (or `/aa`) opens the games. `/arcade hangman` goes straight to Hangman.
- **Random word:** choose a category (or Anything) and click the letters. A wrong letter takes an attempt (six in all). **Hint** shows one letter you did not guess and takes an attempt; one per round. **Give up** shows the word. **New round** picks another word (not one you had lately).
- **Own word:** choose *Own word* and press *New round*. One types a word (the letters are hidden) and an optional hint, then hands over the computer.
- Your statistics (rounds, wins, win rate, streak) and the last ten words are saved per character.

Install like any addon: the folder must be called `AllemanoArcade`. It needs no other addon.

## What is in it

- `UI.lua`: the Allemano look (lime for Arcade) on its own: fills, rounded corners, text, buttons, a choice list, a tooltip.
- `Window.lua`: the window, the home page with a card per game, and the breadcrumb.
- `Games/Hangman/`: `Words.lua` (the word lists), `Logic.lua` (the rules as plain functions), `Stats.lua`, `View.lua` (the screen).
- Tests: `lua Tests/logic_test.lua` (rules, every word playable, statistics) and `lua Tests/smoke_test.lua` (the whole window played through a fake game), run on every push.
