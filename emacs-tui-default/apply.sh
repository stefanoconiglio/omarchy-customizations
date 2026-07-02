#!/usr/bin/env bash
set -euo pipefail

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cp "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

ensure_line() {
  local file="$1"
  local pattern="$2"
  local line="$3"

  if grep -Eq "$pattern" "$file"; then
    sed -i -E "s|$pattern|$line|" "$file"
  else
    printf '\n%s\n' "$line" >>"$file"
  fi
}

home_dir="${HOME:?}"
local_bin="$home_dir/.local/bin"
applications_dir="$home_dir/.local/share/applications"
uwsm_default="$home_dir/.config/uwsm/default"
uwsm_env="$home_dir/.config/uwsm/env"
emacs_wrapper="$local_bin/emacs"
desktop_file="$applications_dir/emacs-tui.desktop"

mkdir -p "$local_bin" "$applications_dir" "$(dirname "$uwsm_default")"

backup_file "$uwsm_default"
backup_file "$uwsm_env"
backup_file "$desktop_file"
backup_file "$emacs_wrapper"

cat >"$emacs_wrapper" <<'EOF'
#!/bin/bash

if [[ -t 0 ]]; then
  exec /usr/bin/emacs -nw "$@"
else
  exec xdg-terminal-exec --app-id=org.omarchy.emacs -e /usr/bin/emacs -nw "$@"
fi
EOF
chmod +x "$emacs_wrapper"

cat >"$desktop_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Emacs TUI
Comment=Edit text files in terminal Emacs
Exec=xdg-terminal-exec --app-id=org.omarchy.emacs -e /usr/bin/emacs -nw %F
Icon=emacs
Terminal=false
Categories=Utility;TextEditor;
MimeType=text/english;text/plain;text/markdown;text/x-markdown;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;application/xml;text/xml;
EOF

if [[ ! -f "$uwsm_default" ]]; then
  cat >"$uwsm_default" <<'EOF'
# Changes require a restart to take effect.

export TERMINAL=xdg-terminal-exec
export EDITOR=emacs
EOF
else
  ensure_line "$uwsm_default" '^export EDITOR=.*' 'export EDITOR=emacs'
fi

if [[ -f "$uwsm_env" ]]; then
  ensure_line "$uwsm_env" '^export PATH=.*' 'export PATH=$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH'
fi

rm -f "$local_bin/fresh"

if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default emacs-tui.desktop \
    text/plain \
    text/english \
    text/markdown \
    text/x-markdown \
    text/x-makefile \
    text/x-c++hdr \
    text/x-c++src \
    text/x-chdr \
    text/x-csrc \
    text/x-java \
    text/x-moc \
    text/x-pascal \
    text/x-tcl \
    text/x-tex \
    application/x-shellscript \
    text/x-c \
    text/x-c++ \
    application/xml \
    text/xml
fi

export EDITOR=emacs
export PATH="$HOME/.local/share/omarchy/bin:$HOME/.local/bin:$PATH"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment EDITOR PATH >/dev/null 2>&1 || true
fi

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment EDITOR PATH >/dev/null 2>&1 || true
fi

printf 'Emacs TUI defaults applied.\n'
printf 'EDITOR=%s\n' "$EDITOR"
printf 'emacs=%s\n' "$(command -v emacs || true)"
