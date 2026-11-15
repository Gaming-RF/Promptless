# Promptless: Bounce Back (jam build, Godot 4.7)

Two jobs, ~3 minutes. Job 1: read Dex's email -> `grep Comets notes.txt` -> `open ball_3.png`
-> stretch the window until the ball is round -> SNAP -> Send. Job 2 (the medal) lands on the
same desktop: same pattern, two text files, eight photos, nothing clickable.

- **Run:** `godot --path .` (or F5 in the editor)
- **Tests:** `godot --headless --path . -s tests/run_tests.gd` (logic + desktop) and
  `godot --headless --path . -s tests/input_test.gd` (real key/mouse events, full 90-second path)
- **Content:** `data/campaign.json` holds the title, end screen, music, job order and shared
  strings (`defaults`, merged into every job). Each job is one file (`data/job_*.json`): email,
  search word, text files, pictures, answer, target size, replies. Add a job = add a file and
  list it in `campaign.json`. No themed strings live in `scripts/`.
  `tests/run_tests.gd` checks every job against the plan's rules (one grep hit, email <60 words,
  replies <30, every picture opens with one side at the target).
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
- Clicking the red command in the email pastes it into the terminal (job 1 only).
- Terminal: Tab completes commands and file names; Up/Down recall history.
- Jobs only need `ls`, `grep`, `open` (`cd`, `ls -a` and `man` also work, for later chapters). Also working, Linux-style: `help cat head less echo pwd
  history alias ps clear mv` (`mv` says the client folder is read-only; `alias` shows `open` is
  the previous owner's shortcut). Typos get "did you mean".
- Files: client folders are read-only; your home folder (`~`) is writable and every SNAP is
  saved there (`ls ~`, `open ~/snapshot_1.png`). Jobs can add folders and hidden files with
  `extra_files` in their JSON.
- "music: on/off" button bottom-right.
