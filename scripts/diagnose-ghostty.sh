#!/usr/bin/env bash
#
# Dump everything relevant about a Ghostty setup in one pass.
#
#   ./scripts/diagnose-ghostty.sh
#
# Read-only: inspects and prints, changes nothing. Every check reports
# regardless of what came before, so a missing binary or file never hides the
# rest of the picture.

set -uo pipefail   # deliberately NOT -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
APPSUP="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

hr(){ printf '\n----- %s -----\n' "$1"; }

hr "1. Is Ghostty installed?"
echo "Ghostty.app:  $(ls -d /Applications/Ghostty.app 2>/dev/null || echo 'NOT in /Applications')"
echo "ghostty CLI:  $(command -v ghostty 2>/dev/null || echo 'NOT on PATH')"
if command -v ghostty >/dev/null 2>&1; then
  echo "version:      $(ghostty +version 2>&1 | head -1)"
else
  # The cask does not always expose the CLI on PATH; the binary lives in the app.
  INAPP=/Applications/Ghostty.app/Contents/MacOS/ghostty
  if [[ -x "$INAPP" ]]; then
    echo "NOTE: CLI missing from PATH but present inside the app bundle."
    echo "      Use: $INAPP +show-config"
  fi
fi
echo "brew cask:    $(brew list --cask ghostty >/dev/null 2>&1 && echo installed || echo 'NOT installed via brew')"

hr "2. Config file: ~/.config (the stowed one)"
echo "path: $XDG_CFG"
if [[ -L "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" ]]; then
  echo "  ~/.config/ghostty is a SYMLINK -> $(readlink "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty")"
elif [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" ]]; then
  echo "  ~/.config/ghostty is a real DIRECTORY (stow did not link it)"
else
  echo "  ~/.config/ghostty DOES NOT EXIST  <-- stow never linked this package"
fi
if [[ -e "$XDG_CFG" ]]; then
  echo "  file exists, $(wc -c <"$XDG_CFG" | tr -d ' ') bytes, readable=$([[ -r "$XDG_CFG" ]] && echo yes || echo NO)"
  echo "  --- contents ---"
  sed 's/^/  | /' "$XDG_CFG" 2>/dev/null || echo "  | (could not read)"
else
  echo "  FILE DOES NOT EXIST"
fi

hr "3. Config file: Application Support (overrides the above)"
echo "path: $APPSUP"
if [[ -e "$APPSUP" ]]; then
  echo "  exists, $(wc -c <"$APPSUP" | tr -d ' ') bytes"
  if grep -qE '[^[:space:]]' "$APPSUP" 2>/dev/null; then
    echo "  ** HAS CONTENT — this OVERRIDES ~/.config/ghostty/config **"
    sed 's/^/  | /' "$APPSUP"
  else
    echo "  empty/whitespace only — harmless, shadows nothing"
  fi
else
  echo "  does not exist — fine, nothing is shadowing the stowed config"
fi

hr "4. What Ghostty ACTUALLY loaded"
GH="$(command -v ghostty 2>/dev/null || echo /Applications/Ghostty.app/Contents/MacOS/ghostty)"
if [[ -x "$GH" ]]; then
  loaded="$("$GH" +show-config 2>&1)"
  printf '%s\n' "$loaded" | grep -E '^(font-family|font-size|theme|background-opacity) ' | sed 's/^/  /'
  [[ -z "$loaded" ]] && echo "  (+show-config returned nothing)"
else
  echo "  cannot run ghostty — skipping"
fi

hr "5. Font"
if [[ -x "$GH" ]]; then
  want="$(sed -n 's/^[[:space:]]*font-family[[:space:]]*=[[:space:]]*//p' "$XDG_CFG" 2>/dev/null | head -1)"
  echo "  config wants: '${want:-<none>}'"
  echo "  installed files matching Monaspice:"
  ls "$HOME/Library/Fonts" 2>/dev/null | grep -i monaspice | head -3 | sed 's/^/    /' \
    || echo "    NONE — run: brew bundle --file=brew/Brewfile.core"
  echo "  ghostty resolves 'Hello' to:"
  "$GH" +show-face --string=Hello 2>&1 | head -1 | sed 's/^/    /'
fi

hr "6. Environment"
echo "  XDG_CONFIG_HOME = ${XDG_CONFIG_HOME:-<unset, so ~/.config is used>}"
echo "  repo config     = $DOTFILES/ghostty/.config/ghostty/config"
echo "  repo HEAD       = $(git -C "$DOTFILES" rev-parse --short HEAD 2>/dev/null)"
echo "  repo up to date = $(git -C "$DOTFILES" fetch -q origin 2>/dev/null; \
  [[ "$(git -C "$DOTFILES" rev-parse HEAD)" == "$(git -C "$DOTFILES" rev-parse origin/main 2>/dev/null)" ]] \
  && echo yes || echo 'NO — run: git pull')"

printf '\nSend this whole output back.\n'
