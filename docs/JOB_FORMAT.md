# Job file format (frozen)

A campaign (`data/campaign.json`, `data/full/campaign.json`) lists jobs. Each job is one JSON
file. `campaign.defaults` is merged under every job, so a job states only what is its own.
`JobData.validate()` checks all of this on load.

## Campaign file

| Key | Meaning |
|---|---|
| `extends` | Another campaign to inherit from (its `jobs` are not inherited) |
| `title`, `tagline`, `boot_button`, `continue_button`, `new_game_button` | Title screen |
| `jobs` | Job file paths in order. An entry that is a **list** = those jobs run at once (inbox tabs) |
| `save` | `true` = autosave + continue |
| `music` | Path of the radio's loop |
| `end` | `{again, picture_job}`: end-screen button text, which job's answer bounces |
| `replay_button`, `best_label` | Timed-replay buttons on the title |
| `defaults` | Merged under every job: `client`, `picture_dir`, `home`, `users`, `replies`, `shell` (all terminal text + man pages), `ui` (all button/label text) |

## Job file

### Always

| Key | Meaning |
|---|---|
| `folder` | The client's folder, absolute (`/clients/dex`). Read-only unless under the home folder |
| `email` | `{from, subject, body, clickable: [commands shown as paste links]}`; body < 60 words |
| `texts` | `{"notes.txt": [lines...]}`, text files in the folder (may be `{}`) |
| `pictures` | `[{file, open_size: [w, h], placeholder?, asset?}]`, pictures in the folder (may be `[]`) |
| `replies` | Client answers by verdict. A value can be a string or a list (one per strike). Each < 30 words |
| `client` | `{name, portrait_calm, portrait_panic}` (usually from defaults) |

### The win rule: `check`

| `check` | Needs | Wins when | Replies needed |
|---|---|---|---|
| `stretch` (default) | `answer`, `target: {w, h, tolerance}` | snapshot holds only the answer, sized within tolerance | `right wrong_file wrong_shape wrong_size` |
| `overlay` | `overlay: {top, under, align, either?}` | `top` traced, on top, lined up with `under` within `align` px (`either`: either may be on top) | `right wrong_file wrong_shape` |
| `join` | `join: {order: [...], by_name?}` | the pages are joined in that order (`by_name`: match file names, not paths) | `right wrong_file wrong_shape` |
| `ran` | `ran: {path, root?}` | that script runs (as root if `root`) | `right` |
| `remote` | `remote: {user, folder, texts, pictures, goal: {opened}}` | `write USER ...` makes their machine open `goal.opened` | `right` |

All jobs also use `no_attachment` (from defaults).

### Optional

| Key | Meaning |
|---|---|
| `search_word` | The grep word. Tests check exactly one line contains it and the email spells it the same |
| `tools` | Any of `trace` (TRACE button), `join` (snapping), `textview` (open text files in a window) |
| `single` | Stretch job: more than one open copy of the answer → reply `crowded` |
| `strikes` | Wrong answers before the client gives up (reply `give_up`) and the job restarts |
| `shuffle` | On restart pick a new answer; write `{answer_n}` in texts/email where its number goes |
| `sticky` | `{lines: [...], paste: bool}`, the sticky note; `paste` = clicking a line pastes it |
| `timed` | Becomes a timed replay on the title once beaten |
| `users` | `{name: {password, sudo, home?}}` for `su` / `sudo` |
| `home` | Your home folder (default `/home/you`) |
| `alt` | `{on: "send_empty", ending, reply}`: sending with nothing attached is another way to finish |
| `ending` | Name recorded when this job is won normally (e.g. `run`) |
| `extra_files` | More files and folders, below |

### `extra_files`

Each entry has `path` (relative to `folder`, or absolute; `~/` works in `makes`) and `type`:

| `type` | Extra fields |
|---|---|
| `dir` | `private` (only its owner and root may enter) |
| `text` | `lines`, `r: false` (unreadable), `private` |
| `picture` | `open_size`, `asset` (default `picture_dir` + file name), `placeholder` |
| `script` | `x` (runnable), `prints` (lines it prints), `opens` or `makes` (a picture it shows/creates), `copies`, `parent` (windowless parent program), `needs_root` |
| `archive` | `contents` (entries like these, paths inside the archive), `password` |

### Placeholder art

Until a real picture exists at `asset`, a picture draws `placeholder.kind`:
`ball`, `ring` (lake + compass ring), `grid` (chart), `lines` (memo text), `mark` (`row`: circled
line, for tracing sheets), `half` (`side`: left/right faded photo), `label` (`text`).
Dropping a PNG at the asset path replaces it. Placeholders are for development only.
