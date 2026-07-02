# Emacs TUI Default for Omarchy

Make Omarchy and Nautilus open Emacs in terminal mode by default.

This is for systems where GUI Emacs is not wanted, and `emacs` should mean
`emacs -nw` everywhere practical.

## What It Does

`apply.sh` applies these user-level changes:

- Creates `~/.local/bin/emacs` as a wrapper around `/usr/bin/emacs -nw`.
- Sets `EDITOR=emacs` in `~/.config/uwsm/default`.
- Ensures `~/.local/bin` is early in `PATH` via `~/.config/uwsm/env`.
- Removes the obsolete `~/.local/bin/fresh` workaround if present.
- Creates `~/.local/share/applications/emacs-tui.desktop`.
- Sets XDG MIME defaults for Markdown, plain text, shell scripts, XML, and
  common source-code text types to `emacs-tui.desktop`.
- Imports `EDITOR` and `PATH` into the live user session when possible.

The script backs up modified existing files with a timestamp suffix before
rewriting them.

## Usage

```bash
./apply.sh
```

After running it, Omarchy config editor actions such as `Setup -> Monitors`
should use terminal Emacs, and double-clicking text or Markdown files in
Nautilus should open them in terminal Emacs.

If an already-running process still has an old environment, log out and back
in.

## Caveat

This intentionally shadows `/usr/bin/emacs` with `~/.local/bin/emacs`.

That means typing `emacs` will open terminal Emacs by default. To launch the
system binary directly, use:

```bash
/usr/bin/emacs
```
