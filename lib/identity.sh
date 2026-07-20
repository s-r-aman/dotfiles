#!/usr/bin/env bash
#
# Identity and secrets. Interactive by design.
#
# Nothing here is stored in the repo. Git identity is written to
# ~/.gitconfig.local, which the stowed ~/.gitconfig includes but which is
# never committed.
#
# Safe to re-run: every step detects existing state and offers to keep it.

set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=''; GREEN=''; YELLOW=''; RESET=''
fi
info() { printf '    %s\n' "$1"; }
ok()   { printf '    %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '    %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }

# Non-interactive shell (CI, piped): skip rather than hang on `read`.
if [[ ! -t 0 ]]; then
  warn "not a terminal — skipping identity setup."
  warn "run manually: bash lib/identity.sh"
  exit 0
fi

# --- git identity --------------------------------------------------------
GITCONFIG_LOCAL="$HOME/.gitconfig.local"

if [[ -f "$GITCONFIG_LOCAL" ]] && git config --file "$GITCONFIG_LOCAL" user.email >/dev/null 2>&1; then
  ok "git identity already set: $(git config --file "$GITCONFIG_LOCAL" user.name) <$(git config --file "$GITCONFIG_LOCAL" user.email)>"
else
  printf '\n    %sGit identity%s (written to ~/.gitconfig.local, never committed)\n' "$BOLD" "$RESET"
  read -r -p "      Name:  " git_name
  read -r -p "      Email: " git_email

  if [[ -n "$git_name" && -n "$git_email" ]]; then
    git config --file "$GITCONFIG_LOCAL" user.name "$git_name"
    git config --file "$GITCONFIG_LOCAL" user.email "$git_email"
    ok "wrote $GITCONFIG_LOCAL"
  else
    warn "skipped — commits will fail until user.name and user.email are set"
  fi
fi

# --- ssh key -------------------------------------------------------------
SSH_KEY="$HOME/.ssh/id_ed25519"

if [[ -f "$SSH_KEY" ]]; then
  ok "SSH key already exists at $SSH_KEY"
else
  printf '\n    %sSSH key%s\n' "$BOLD" "$RESET"
  read -r -p "      Generate an ed25519 key? [Y/n] " reply
  if [[ ! "$reply" =~ ^[Nn] ]]; then
    key_comment="${git_email:-$(git config --file "$GITCONFIG_LOCAL" user.email 2>/dev/null || echo "$USER@$(hostname -s)")}"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$key_comment" -f "$SSH_KEY"

    # Persist the key in the keychain across reboots.
    cat >> "$HOME/.ssh/config" <<'EOF'

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY"
    ok "key generated and added to the agent"

    if command -v pbcopy >/dev/null 2>&1; then
      pbcopy < "${SSH_KEY}.pub"
      ok "public key copied to clipboard — add it at https://github.com/settings/keys"
    fi
  fi
fi

# --- github cli ----------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ok "gh already authenticated"
  else
    printf '\n    %sGitHub CLI%s — required by the ghpr/myprs/ghrr aliases in .zshrc\n' "$BOLD" "$RESET"
    read -r -p "      Run 'gh auth login' now? [Y/n] " reply
    [[ "$reply" =~ ^[Nn] ]] || gh auth login
  fi
else
  warn "gh not installed — skipping (it is in Brewfile.core)"
fi

# --- remaining manual items ---------------------------------------------
cat <<EOF

    ${BOLD}Still manual${RESET} — these cannot be scripted:
      - Unlock Bitwarden, then sign into the apps whose licences it holds
      - Sign into the App Store (needed before the mas tier will install)
      - Grant Accessibility to Karabiner-Elements and Raycast
EOF
