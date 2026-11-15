# Toy-phase decisions

## Core concept: help them bounce back
The jam theme is the game's spine, not decoration. Every client is first **fixed** (you shape their
file for them) and then **taught**: they come back, you can't touch their files, and you coach their
own machine with `write NAME COMMAND`. A taught client "bounced back" from losing their AI; the end
screen lists everyone who did ("THE TOWN IS BOUNCING BACK"). Wrong answers still "bounce back" as
replies, and the fixed ball bounces. Jam build: job 1 fix Dex's ball, job 2 teach Dex.

Every open question the plan parked "until after the jam", with the answer that is built and
tested. Each can be changed; the reason is here so the change is deliberate.

## Engine and code
- **Engine:** Godot 4.7 for both the jam and the full game (the plan allows Godot). The jam draft
  was restructured rather than thrown away: desktop and shell are each split in two
  (`desktop_windows.gd` / `desktop.gd`, `shell_core.gd` / `shell.gd`), all content is data, and
  two test suites (logic + real input) cover every feature.
- **Screen:** stays 640×360. Job 1, two text windows and a picture fit with room to drag
  (checked in screenshots at actual size). It gets crowded with 4+ windows, so windows open in
  cascades, pictures can be dragged by the picture, and large-text mode exists. Revisit only if
  playtests say it's cramped.

## Controls
- **Tracing mode:** a TRACE button in each picture window's title bar (reads TRACING when on),
  or the T key. Only in jobs with the `trace` tool.
- **Snapshot:** the plan's drag-a-rectangle tool is the SNAPSHOT button in the bottom bar: drag a
  rectangle; every picture window *fully* inside is recorded. Esc cancels. Each picture window
  also keeps a SNAP button, which records exactly that window plus its joined pages and any
  window it is tracing over (or that is tracing over it). It never picks up an unrelated window
  hidden behind it.
- **A snapshot of several pictures is not a stretch answer:** stretch jobs need the answer alone
  ("the snapshot is of the ball 3 window").
- **Keyboard only:** Esc leaves the terminal for the pictures (and back); Tab picks the next
  picture; arrows stretch (Shift ×8); Ctrl+arrows move (and join); S snapshot; T trace; Enter send.
  These shortcuts only work after Esc. After clicking a picture with the mouse, arrows still
  stretch it, but any typing goes back to the terminal, so a stray `s` or Enter can't snap or send.
- **Un-joining:** not supported; joined pages stay joined until the job ends.

## Shell
- **Quoted words:** supported (`grep "Comets game" notes.txt`).
- **Wildcards:** `*` and `?` are supported, expanded before the command like bash; quoted words
  and patterns that match nothing stay literal (bash's default).
- **Flags that work:** `ls -a -l`, `grep -i`, `head -n N` / `-N`, `sort -r -n`, `unzip -d DIR`,
  `chmod +x -x +r -r 755`; `cd ..`, `cd ~`, `cd`. Other flags are ignored, not errors.
- **Not supported, said plainly:** pipes and `>` ("not supported by this shell").
- **`alias`** prints `alias open='pixview'   # set up by the previous owner`.
- **New command:** `write USER COMMAND` for the final job (real Unix `write` sends to another
  user's terminal; here their machine runs the line exactly as typed).

## Chapter 3: Tobi's flood
- The copies come from a **windowless parent program** (`chart.sh`, visible only in `ps`).
  Killing a copy just respawns it; killing the parent ends the flood.
- That makes `ps` a taught command, which would give chapter 3 four new tools. Decision: **`ps`
  and `kill` count as one tool ("stopping programs")**: `kill` is useless without the numbers,
  and the title bars already teach PIDs. Chapter 3 stays at cp, chmod, ps+kill.

## Saving
- Continue restores the job (and a reshuffled answer), open windows (size, place, tracing),
  home folder, mail, folder, history, strikes, radio and text size.
- **Not restored:** which pictures were joined, and a running windowless parent program
  (Tobi's flood). After continue, re-join the pages / re-run the script.

## Mail as files
- **Yes.** Every email received is saved as `~/mail/NN_client.txt`, and replies are appended.
  Old letters stay across jobs, so `grep` finds them (Ansel's password is a terminal step).

## Puzzle patterns (the plan's six)
1. `stretch` (ch0–1), 2. `overlay` (ch1–2), 3. `stretch` + `single` / the flood (ch3),
4. `join` (ch4), 5. `ran`: run the right command as the right user (ch5),
6. `remote`: teach Dex by `write` (final job).

## Story (draft answers for the writers)
- **When the final command is runnable:** from chapter 5's job, after the player has found the
  hidden folder in their own home (chapter 2's story beat) and pieced together her password.
- **The choice:** run it (`sudo` her script → ending `run`), or reply to Ansel with nothing
  attached (ending `wait`). The ending is recorded in `user://records.json`.
- **If it's never run:** the credits still roll after Dex's lesson; the inbox stays full. Her
  script stays on the machine ("the command is still sitting there when the credits end").
- **How an offline machine reaches the assistants:** the script "signs a message" that goes out
  as an ordinary email (the plan's own suggestion), shown in its output.
- **Placeholders for the writers:** her name (user `owner`), her notes, her password
  (`harbor1984`), Ansel's chapter 5 letter.
