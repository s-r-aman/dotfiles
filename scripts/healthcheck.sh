#!/usr/bin/env bash
#
# Verify a bootstrapped machine against the success criteria in
# docs/superpowers/specs/2026-07-20-new-mac-bootstrap-design.md
#
# Read-only: checks and reports, never fixes. Exits non-zero if anything
# failed, so it is usable as a gate.

set -uo pipefail   # deliberately NOT -e: we want every check to run

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; RESET=''
fi

pass_count=0
fail_count=0

pass() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; ((pass_count++)); }
fail() { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; ((fail_count++)); }

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then pass "$1"; else fail "$1 not on PATH"; fi
}

printf '\n%sCommands%s\n' "$BOLD" "$RESET"
for c in brew stow zsh starship zoxide eza bat fd fzf jq nvim tmux gh mas; do
  check_cmd "$c"
done

# The specific regression that motivated this rewrite: .zshrc aliases call
# eza, but the old cli-utils.sh installed exa.
printf '\n%sShell aliases resolve%s\n' "$BOLD" "$RESET"
if command -v eza >/dev/null 2>&1; then
  pass "eza present (ll/lla/lsa will work)"
else
  fail "eza missing — ll/lla/lsa are broken"
fi

printf '\n%soh-my-zsh%s\n' "$BOLD" "$RESET"
[[ -d "$HOME/.oh-my-zsh" ]] && pass "framework installed" || fail "~/.oh-my-zsh missing"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ -d "$ZSH_CUSTOM_DIR/plugins/$p" ]]; then
    pass "plugin $p"
  else
    fail "plugin $p missing — every new shell will print an error"
  fi
done

printf '\n%sStow links%s\n' "$BOLD" "$RESET"
# Checks that a path RESOLVES into the dotfiles repo, rather than demanding a
# symlink at that exact path.
#
# stow folds trees: if ~/.claude does not already exist it links ~/.claude
# itself, so ~/.claude/commands is then a real directory reached *through* a
# link and `-L` on it is false. Both layouts are correct, and which one you
# get depends on what already existed. Testing `-L` at a fixed path reports a
# spurious failure on exactly the fresh machine this script is meant to check.
check_link() {
  local target="$1" real
  if [[ ! -e "$target" ]]; then
    fail "$target missing"
    return
  fi
  real="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")"
  if [[ "$real" == "$DOTFILES"/* ]] || [[ "$(readlink "$target" 2>/dev/null)" == *dotfiles* ]]; then
    pass "$(basename "$target") -> dotfiles"
  else
    # Resolve one more level for the folded case: the parent may be the link.
    local parent_real
    parent_real="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)"
    if [[ "$parent_real" == "$DOTFILES"/* ]]; then
      pass "$(basename "$target") -> dotfiles (via folded parent)"
    else
      fail "$target does not resolve into $DOTFILES (got $parent_real)"
    fi
  fi
}
check_link "$HOME/.zshrc"
check_link "$HOME/.tmux.conf"
check_link "$HOME/.gitconfig"
for d in karabiner nvim ghostty alacritty; do check_link "$HOME/.config/$d"; done
check_link "$HOME/.claude/commands"

printf '\n%sGhostty%s\n' "$BOLD" "$RESET"

# Ghostty reads the macOS-native Application Support config IN ADDITION to
# ~/.config/ghostty/config, and it takes precedence. Ghostty rewrites it from
# its GUI, so it can reappear at any time and silently shadow the stowed
# config — everything looks correctly linked and simply has no effect.
GHOSTTY_APPSUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [[ -f "$GHOSTTY_APPSUPPORT" ]] && grep -qE '[^[:space:]]' "$GHOSTTY_APPSUPPORT" 2>/dev/null; then
  fail "a config in Application Support is OVERRIDING the stowed one:"
  fail "  $GHOSTTY_APPSUPPORT"
  fail "  move it aside, then restart Ghostty"
else
  pass "no shadowing config in Application Support"
fi

if [[ -r "$HOME/.config/ghostty/config" ]]; then
  pass "config readable"
  # The font-family declared in the stowed config, used for both checks below.
  # NOTE: BSD sed has no \s — use [[:space:]] or the space is never stripped.
  want_font="$(sed -n 's/^[[:space:]]*font-family[[:space:]]*=[[:space:]]*//p' \
                 "$HOME/.config/ghostty/config" 2>/dev/null | head -1)"

  if command -v ghostty >/dev/null 2>&1; then
    # +show-config prints what Ghostty ACTUALLY loaded, which is the only
    # reliable signal — a linked-but-unreadable config looks identical to a
    # missing one from the outside.
    #
    # Capture to a variable rather than piping into grep -q. Under `pipefail`,
    # grep -q exits on its first match, SIGPIPEs ghostty, and the pipeline then
    # reports failure even though the match succeeded — a race that passes or
    # fails depending on which process finishes first.
    loaded="$(ghostty +show-config 2>/dev/null || true)"
    if [[ -n "$want_font" && "$loaded" == *"font-family = $want_font"* ]]; then
      pass "ghostty is loading this config"
    elif [[ -z "$loaded" ]]; then
      fail "ghostty +show-config returned nothing"
    else
      fail "ghostty is NOT loading the stowed config (check: ghostty +show-config)"
    fi
  fi

  # A font named in the config must actually be installed, or Ghostty silently
  # falls back to a system default and the terminal just looks wrong — which is
  # indistinguishable from the config not loading at all.
  if [[ -n "$want_font" ]]; then
    if ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi "${want_font// /}"; then
      pass "font installed: $want_font"
    else
      fail "font NOT installed: '$want_font' — ghostty falls back to a default."
      fail "  install it with: brew bundle --file=brew/Brewfile.core"
      fail "  (nerd-patched Monaspace is the cask font-monaspace-nerd-font)"
    fi
  fi
else
  # "not readable" alone conflates three very different faults. Say which.
  gdir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  gcfg="$gdir/config"
  if [[ -L "$gdir" && ! -e "$gdir" ]]; then
    fail "~/.config/ghostty is a DANGLING symlink -> $(readlink "$gdir")"
    fail "  the repo is not at that path on this machine"
  elif [[ ! -e "$gdir" ]]; then
    fail "~/.config/ghostty does not exist — stow never linked the package"
    fail "  fix: cd $DOTFILES && stow --target=\"\$HOME\" ghostty"
  elif [[ ! -e "$gcfg" ]]; then
    fail "~/.config/ghostty exists but contains no 'config' file"
    fail "  it resolves to: $(cd "$gdir" 2>/dev/null && pwd -P)"
    fail "  contents: $(ls -A "$gdir" 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || echo '<empty>')"
    fail "  repo has: $(ls -A "$DOTFILES/ghostty/.config/ghostty" 2>/dev/null | tr '\n' ' ' || echo '<package missing>')"
  else
    fail "~/.config/ghostty/config exists but is not readable (permissions?)"
    fail "  $(ls -la "$gcfg" 2>&1 | head -1)"
  fi
fi

printf '\n%sGit identity%s\n' "$BOLD" "$RESET"
if git config user.email >/dev/null 2>&1; then
  pass "identity set: $(git config user.name) <$(git config user.email)>"
else
  fail "git user.email unset — run lib/identity.sh"
fi
# Identity must NOT have leaked into the tracked config.
if [[ -f "$DOTFILES/git/.gitconfig" ]] && grep -qE '^\s*(email|name)\s*=' "$DOTFILES/git/.gitconfig"; then
  fail "identity leaked into the tracked git/.gitconfig — move it to ~/.gitconfig.local"
else
  pass "no identity in tracked gitconfig"
fi

printf '\n%sgit-lfs%s\n' "$BOLD" "$RESET"
if git config --get filter.lfs.clean >/dev/null 2>&1; then
  if command -v git-lfs >/dev/null 2>&1; then
    pass "lfs configured and binary present"
  else
    fail "gitconfig sets filter.lfs.* but git-lfs is not installed"
  fi
fi

printf '\n%smacOS defaults%s\n' "$BOLD" "$RESET"
check_default() {
  local domain="$1" key="$2" want="$3" got
  got="$(defaults read "$domain" "$key" 2>/dev/null)" || { fail "$key unset (want $want)"; return; }
  [[ "$got" == "$want" ]] && pass "$key = $got" || fail "$key = $got (want $want)"
}
check_default -g KeyRepeat 2
check_default -g InitialKeyRepeat 25
check_default com.apple.dock autohide 1
check_default com.apple.dock mru-spaces 0
check_default com.apple.finder ShowPathbar 1

printf '\n%s%d passed, %d failed%s\n\n' "$BOLD" "$pass_count" "$fail_count" "$RESET"
[[ $fail_count -eq 0 ]]
