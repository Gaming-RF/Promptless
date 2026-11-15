# Promptless: Bounce Back (jam build, Godot 4.7)

One job, ~90 seconds: read Dex's email -> `grep Comets notes.txt` -> `open ball_3.png`
-> stretch the window until the ball is round -> SNAP -> Send.

- **Run:** `godot --path .` (or F5 in the editor)
- **Tests:** `godot --headless --path . -s tests/run_tests.gd` (logic + desktop) and
  `godot --headless --path . -s tests/input_test.gd` (real key/mouse events, full 90-second path)
- **Theme:** everything themed (email, notes, file names, answer, target size, replies,
  shell lines) is in `data/job_bounce_back.json`. No themed strings live in `scripts/`.
- **Web export:** install export templates, then Project > Export > Web (preset included;
  it already ships `data/*.json`).

- **After dropping in assets:** open the editor once (or `godot --headless --path . --import`)
  so Godot imports them, otherwise they won't load.
- **Web embed size:** integer scaling, so make the embed a multiple of 640x360 (1280x720, 1920x1080)
  or it shows at 1x with borders.

## Assets
All current assets are free CC0 / OFL downloads; sources and licences are in `CREDITS.md`.
To swap one, replace the file with the same name and re-import:

| File | Spec |
|---|---|
| `assets/ball_1.png` ... `ball_5.png` | 160x160, ball perfectly round, transparent bg |
| `assets/dex_calm.png`, `assets/dex_panic.png` | 32x32 portraits |
| `assets/font.ttf` | pixel font; set `FONT_SIZE` in `scripts/ui.gd` to its drawn size |
| `assets/sfx/type`, `mail`, `success` (.wav/.ogg/.mp3) | the three sounds |
| palette | `scripts/palette.gd` |

## Controls
- Drag title bars to move; drag a picture's right/bottom edge or corner to stretch.
- Click a picture, then arrow keys resize 1px (Shift: 8px).
- Clicking the red command in the email pastes it into the terminal.
