# Promptless: Bounce Back (jam build, Godot 4.7)

Help them bounce back. Two jobs, ~3 minutes. Job 1 (fix): read Dex's email -> `grep Comets notes.txt`
-> `open ball_3.png` -> stretch the window until the ball is round -> SNAP -> Send. Job 2 (teach): Dex
wants to learn, so you send commands to his own laptop with `write dex ...` until he opens the
newsletter photo himself. The end screen lists who bounced back.
Title screen: how to play, settings (music, volumes, big text, fullscreen, reset), and a
"full game (draft)" button (remove `other_campaigns` from `data/campaign.json` before a jam upload:
its placeholder art isn't shippable).

- **Run:** `godot --path .` (or F5 in the editor)
- **Full-game draft:** `godot --path . -- --campaign=res://data/full/campaign.json`
  (fix -> teach pairs for Dex, Marguerite, the Okafors and Tobi; Lake Orrin; Ansel + Dex at once;
  the previous owner with the run/wait choice; Dex's last lesson;
  code-drawn placeholder art until real pictures exist at the same file names; all text is a draft)
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
- **Scaling:** the 640x360 game scales smoothly to fill any window or embed, keeping 16:9
  (thin bars if the shape differs). 1280x720 is still the sharpest embed size.

## Docs
- `docs/CONTRACTS.md` — shell↔desktop result, snapshot record, screen/palette
- `docs/JOB_FORMAT.md` — every field a job file can use (checked by `JobData.validate()`)
- `docs/DECISIONS.md` — every Toy-phase decision and why

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
- Keyboard only: Esc leaves the terminal for the pictures (and back), Tab picks the next picture,
  arrows stretch (Shift: 8px), Ctrl+arrows move (joins if it lands next to another), S = SNAP,
  T = trace, Enter = Send.
- "text: big" doubles the text in the terminal, mail and text windows.
- Saving: set `"save": true` in `data/campaign.json` (off for the jam). The title then offers
  continue / new game.
- Clicking the red command in the email pastes it into the terminal (job 1 only).
- Terminal: Tab completes commands and file names; Up/Down recall history.
- Jobs only need `ls`, `grep`, `open`. Later-chapter commands also work: `cd`, `ls -a`, `ls -l`,
  `man`, `cp`, `chmod`, `kill PID` (every window shows its PID in the title bar), `./script`,
  `sort`, `unzip`, `su`, `sudo`, `exit`, `whoami`. Password prompts hide what you type.
  The music is a program too: `kill 103` stops the radio. Also working, Linux-style: `help cat head less echo pwd
  history alias ps clear mv` (`mv` says the client folder is read-only; `alias` shows `open` is
  the previous owner's shortcut). Typos get "did you mean".
- Files: client folders are read-only; your home folder (`~`) is writable and every SNAP is
  saved there (`ls ~`, `open ~/snapshot_1.png`). Jobs can add folders and hidden files with
  `extra_files` in their JSON (`"r": false` = unreadable, `"type": "script"` with `"opens"` and
  `"copies"` = a runnable script that opens picture windows).
- "radio: on/off" button bottom-right.
- Picture windows can be dragged by the picture itself, not just the title bar.
- Window tools a job can switch on with `"tools"`: `"trace"` (TRACE button: see-through tracing
  mode) and `"join"` (pictures dragged edge to edge snap together and move as one). A job's
  `"check"` picks the win rule: `stretch` (default), `overlay` (`"overlay": {top, under, align}`)
  or `join` (`"join": {"order": [...]}`).
- Campaign data: a `jobs` entry can be a list of jobs that run at once (inbox tabs in the mail
  title). A job with `"timed": true` becomes a replay with a clock + best time once beaten.
- Job runner data: `"strikes": 3` + reply lists + `"give_up"`; `"shuffle": true` with `{answer_n}`
  in notes/email; `"sticky": {"lines", "paste"}`; `"tools": ["textview"]` opens text files in a window.
- More job data: `"users"` (password, `sudo`, home), files with `"private": true`, archives
  (`"type": "archive"`, optional `"password"`, `"contents"`).
