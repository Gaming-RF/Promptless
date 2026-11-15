# The three contracts (frozen)

The plan's three borders between people, as they are built. Change them only on purpose,
and update the tests in the same commit.

## 1. Shell ↔ desktop

The shell (`scripts/shell_core.gd` + `scripts/shell.gd`) never touches a window. The desktop
(`scripts/desktop_windows.gd` + `scripts/desktop.gd`) never parses a command. They talk through
one call and one result:

```
var result = shell.run(line, desktop.running_programs())
```

`shell.run()` returns a dictionary. Every key is always present:

| Key | Type | Meaning (desktop acts on it) |
|---|---|---|
| `out` | Array of String | Lines to print in the terminal |
| `hint` | Array of String | Dim lines (did-you-mean, grep hints) |
| `open` | String | Path to show in a viewer (picture or text window); `""` = none |
| `clear` | bool | Clear the terminal |
| `kill` | int | PID to stop; `0` = none |
| `launch` | Dictionary | A script started: `{path, count, parent}` → open `count` windows of `path`; `parent` = name of a windowless parent program |
| `ask` | String | A password prompt to show; the next line typed is the answer (hidden) |
| `ran` | Dictionary | A script ran: `{path, user}` (used by `check: ran` jobs) |
| `write` | Dictionary | `write USER CMD`: `{user, line}` → run `line` on that user's remote machine |

The plan's seven messages map onto it like this:

| Plan message | How it travels |
|---|---|
| open this file in a viewer | `result.open` |
| this file changed | the desktop reads `shell.fs` (the one file system both share) |
| a program started | `result.launch` |
| a program stopped | `result.kill` |
| list the running programs | `desktop.running_programs()` passed into `shell.run()` → `[{pid, cmd, protected?}]` |
| save this new file | `shell.fs.add_file(path, node)`, called by the desktop for snapshots and mail |
| a snapshot was taken | the snapshot record (below), handed to `Judge.verdict(record, job)` |

### The snapshot record

```
{
  "name": "snapshot_3.png",
  "rect": [x, y, w, h],                      # the rectangle that was snapped, game pixels
  "windows": [                               # rectangle tool: every picture window fully inside;
                                             # SNAP button: that window + joined/traced partners
    {"file": "/clients/dex/ball_3.png",
     "w": 160, "h": 160,                     # picture size inside its window
     "x": 327, "y": 21,                      # picture position on the desktop
     "z": 7,                                 # stacking order (higher = on top)
     "tracing": false,
     "group": 0,                             # join group id, 0 = not joined
     "copies": 1}                            # windows open showing the same file
  ],
  "order": ["/home/you/ledger/scan_b.png", "..."]   # joined pages, left→right then top→bottom
}
```

The judge reads only this record. Nothing is measured from pixels.

## 2. Job folder format

See `docs/JOB_FORMAT.md`. `JobData.validate(job)` enforces it: unknown keys, missing fields and
missing replies are reported when a campaign loads, and `tests/run_tests.gd` fails on any.

## 3. Screen, frames and palette

| Thing | Value | Where |
|---|---|---|
| Screen | 640×360, fractional (auto) scaling to fit, aspect kept, `canvas_items` stretch | `project.godot` |
| Title bar | 10 px, 1 px border; active window = lighter bar + 2 px light underline | `desk_window.gd` |
| Palette | Sweetie 16; `CLICK` reserved for clickable things, always with a border, underline or `>` | `palette.gd` |
| Font | Press Start 2P at 8 px (multiples of 8 only) | `ui.gd` `FONT_SIZE` |
| Portraits | 32×32, `assets/<client>_calm.png` / `_panic.png` | job `client` |
| Puzzle pictures | drawn at the job's target size, in the palette | job `pictures` |
| Icons | 16×16 (none in use yet) | — |
