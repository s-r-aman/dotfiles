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
check_link() {
  local target="$1"
  if [[ -L "$target" ]]; then
    local dest; dest="$(readlink "$target")"
    if [[ "$dest" == *dotfiles* ]]; then pass "$(basename "$target") -> $dest"
    else fail "$target is a symlink but not into dotfiles ($dest)"; fi
  elif [[ -e "$target" ]]; then
    fail "$target exists but is a real file, not a stow link"
  else
    fail "$target missing"
  fi
}
check_link "$HOME/.zshrc"
check_link "$HOME/.tmux.conf"
check_link "$HOME/.gitconfig"
for d in karabiner nvim ghostty alacritty; do check_link "$HOME/.config/$d"; done
check_link "$HOME/.claude/commands"

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
