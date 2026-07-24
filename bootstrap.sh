#!/usr/bin/env bash
#
# Bootstrap a Mac from this dotfiles repo.
#
#   git clone <repo> ~/dotfiles && ~/dotfiles/bootstrap.sh
#
# Every phase is idempotent: re-running a completed bootstrap is a no-op that
# exits 0. Nothing here is destructive — stow conflicts are backed up, never
# overwritten.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_DIR="$DOTFILES/brew"

# Stow packages. yabai/skhd were removed deliberately — window management
# moved to Raycast + alt-tab.
STOW_PACKAGES=(agents alacritty claude ghostty git karabiner nvim tmux zshrc)

OPTIONAL_TIERS=(dev apps media ai mas)
SELECTED_TIERS=()

# --- output --------------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; RESET=''
fi

phase() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$RESET"; }
info()  { printf '    %s\n' "$1"; }
ok()    { printf '    %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()  { printf '    %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
die()   { printf '\n%serror:%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Installs the core tier by default: shell, CLI tools, editor, and the desktop
apps needed for a usable machine.

Options:
  --with TIER[,TIER...]   Also install optional tiers.
                          Available: dev, apps, media, ai, mas
  --all                   Install every tier.
  --skip-macos            Do not apply macOS system defaults.
  --skip-identity         Do not run the interactive identity checklist.
  -h, --help              Show this message.

Examples:
  ./bootstrap.sh                      # core only — fastest usable machine
  ./bootstrap.sh --with dev,apps      # core + dev + apps
  ./bootstrap.sh --all                # everything
EOF
}

# --- args ----------------------------------------------------------------
SKIP_MACOS=false
SKIP_IDENTITY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with)
      [[ $# -ge 2 ]] || die "--with requires a tier list (e.g. --with dev,apps)"
      IFS=',' read -ra requested <<< "$2"
      for tier in "${requested[@]}"; do
        # shellcheck disable=SC2076
        [[ " ${OPTIONAL_TIERS[*]} " == *" $tier "* ]] \
          || die "unknown tier '$tier'. Available: ${OPTIONAL_TIERS[*]}"
        SELECTED_TIERS+=("$tier")
      done
      shift 2
      ;;
    --all)          SELECTED_TIERS=("${OPTIONAL_TIERS[@]}"); shift ;;
    --skip-macos)   SKIP_MACOS=true; shift ;;
    --skip-identity) SKIP_IDENTITY=true; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "unknown option '$1' (try --help)" ;;
  esac
done

# =========================================================================
# Phase 1 — preflight
# =========================================================================
phase "Phase 1/7  Preflight"

[[ "$(uname -s)" == "Darwin" ]] || die "this bootstrap is macOS-only (found $(uname -s))"

case "$(uname -m)" in
  arm64) BREW_PREFIX="/opt/homebrew" ;;
  x86_64)
    BREW_PREFIX="/usr/local"
    warn "Intel Mac detected. .zshrc hardcodes /opt/homebrew in PATH and the"
    warn "nvm source lines; you will need to adjust it after stowing."
    ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac
ok "macOS on $(uname -m), brew prefix $BREW_PREFIX"

if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode command line tools present"
else
  info "Installing Xcode command line tools..."
  xcode-select --install || true
  info "Complete the GUI installer, then re-run this script."
  exit 0
fi

# Keep sudo warm so the macOS defaults phase does not stall on a prompt.
if ! sudo -n true 2>/dev/null; then
  info "Some steps need sudo. Prompting once now."
  sudo -v
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# =========================================================================
# Phase 2 — Homebrew
# =========================================================================
phase "Phase 2/7  Homebrew"

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed ($(brew --version | head -1))"
else
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew usable in THIS shell — a fresh install is not yet on PATH.
[[ -x "$BREW_PREFIX/bin/brew" ]] || die "brew not found at $BREW_PREFIX/bin/brew"
eval "$("$BREW_PREFIX/bin/brew" shellenv)"
ok "brew on PATH for this session"

# =========================================================================
# Phase 3 — packages
# =========================================================================
phase "Phase 3/7  Packages"

# Packages rot upstream: taps get deprecated, casks get renamed or removed.
# When that happens `brew bundle` exits non-zero, and under `set -e` that
# would abort the whole run and leave the machine half-configured. Every
# bundle call below is therefore allowed to fail; failures are collected and
# reported at the end, and the exit code reflects them.
FAILED_TIERS=()

FAILED_PACKAGES=()

# Install a Brewfile one entry at a time.
#
# `brew bundle` fetches a tier as a single batch and aborts the whole batch if
# ANY entry fails to resolve. One removed formula or untrusted cask therefore
# costs every other package in that tier — 22 apps lost to one dead cask. This
# fallback salvages the rest and names exactly what is broken.
install_individually() {
  local file="$1" tier="$2"
  local name id rc=0

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    brew install --formula "$name" >/dev/null 2>&1 \
      && info "  ok   formula $name" \
      || { warn "  FAIL formula $name"; FAILED_PACKAGES+=("$tier:$name"); rc=1; }
  done < <(grep '^brew "' "$file" | sed 's/^brew "\([^"]*\)".*/\1/')

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    brew install --cask "$name" >/dev/null 2>&1 \
      && info "  ok   cask $name" \
      || { warn "  FAIL cask $name"; FAILED_PACKAGES+=("$tier:$name"); rc=1; }
  done < <(grep '^cask "' "$file" | sed 's/^cask "\([^"]*\)".*/\1/')

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    mas install "$id" >/dev/null 2>&1 \
      && info "  ok   mas $id" \
      || { warn "  FAIL mas $id"; FAILED_PACKAGES+=("$tier:mas-$id"); rc=1; }
  done < <(grep '^mas ' "$file" | sed 's/.*id: *\([0-9]*\).*/\1/')

  return $rc
}

run_bundle() {
  # Split across two `local` statements deliberately: in bash 3.2 a single
  # `local a=$1 b=$a` declares both names before assigning, so `$a` is unset
  # when `b` expands — fatal under `set -u`.
  local tier="$1"
  local file="$BREW_DIR/Brewfile.$tier"

  if brew bundle --file="$file"; then
    return 0
  fi

  warn "'$tier' failed as a batch — retrying entry by entry to salvage the rest."
  if install_individually "$file" "$tier"; then
    ok "'$tier' fully installed on the second pass"
    return 0
  fi

  FAILED_TIERS+=("$tier")
  return 1
}

# Taps first: the casks in Brewfile.apps resolve only from third-party taps.
info "Tapping repositories..."
run_bundle taps && ok "taps ready"

# Recent Homebrew refuses to load casks from a third-party tap until that tap
# is explicitly trusted (HOMEBREW_REQUIRE_TAP_TRUST), which aborts the entire
# tier containing them. These are the taps declared in Brewfile.taps, each one
# already an explicit choice in this repo, so trusting them here matches
# intent — but it IS granting those taps permission to run their code.
while IFS= read -r t; do
  [[ -n "$t" ]] || continue
  if brew trust --tap "$t" >/dev/null 2>&1; then
    info "  trusted tap $t"
  else
    # Older Homebrew has no `brew trust`; nothing to do there.
    info "  (tap trust not applicable for $t)"
  fi
done < <(grep '^tap "' "$BREW_DIR/Brewfile.taps" | sed 's/^tap "\([^"]*\)".*/\1/')

info "Installing core tier (this is the slow part)..."
run_bundle core && ok "core installed"

# macOS ships bash 3.2, where expanding an EMPTY array under `set -u` is an
# unbound-variable error. A default run selects no optional tiers, so this
# loop must be guarded rather than expanded unconditionally.
for tier in ${SELECTED_TIERS[@]+"${SELECTED_TIERS[@]}"}; do
  if [[ "$tier" == "mas" ]]; then
    # `mas install` fails on a machine not signed into the App Store, and the
    # error is opaque. Check first and degrade to a warning.
    if ! mas account >/dev/null 2>&1; then
      warn "not signed into the App Store — skipping the mas tier."
      warn "sign in via App Store.app, then: brew bundle --file=brew/Brewfile.mas"
      continue
    fi
  fi
  info "Installing $tier tier..."
  run_bundle "$tier" && ok "$tier installed"
done

# =========================================================================
# Phase 4 — stow
# =========================================================================
# MUST run before oh-my-zsh. The oh-my-zsh installer writes a template
# ~/.zshrc unconditionally when no zshrc exists — its KEEP_ZSHRC=yes early
# return sits *inside* `if [ -f .zshrc ] || [ -h .zshrc ]`, so on a clean
# machine it falls straight through and creates one. Linking first means the
# symlink already satisfies that `-h` test, and oh-my-zsh leaves it alone.
phase "Phase 4/7  Linking dotfiles"

command -v stow >/dev/null 2>&1 || die "stow missing — Brewfile.core should have installed it"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STOW_FAILED=()
backed_up_any=false

for pkg in "${STOW_PACKAGES[@]}"; do
  [[ -d "$DOTFILES/$pkg" ]] || { warn "package '$pkg' not in repo — skipping"; continue; }

  # Move aside anything real sitting where a link belongs.
  #
  # This walks the package to compute its targets rather than parsing stow's
  # conflict output. Those messages come in several shapes that vary between
  # releases ("existing target is not owned by stow", "cannot stow X over
  # existing target Y since neither a link nor a directory"), and matching the
  # wrong one silently backs up nothing and then fails to link.
  #
  # A pre-existing SYMLINK is left alone: stow --restow owns and refreshes it.
  # Only real files and directories are moved.
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    target="$HOME/$rel"
    [[ -e "$target" && ! -L "$target" ]] || continue

    # CRITICAL: the target may BE the repo's own file, reached through a
    # symlinked parent.
    #
    # stow folds trees — when ~/.config/ghostty does not exist it links the
    # directory itself, so ~/.config/ghostty/config then resolves into the
    # repo. That path is a regular file (only its PARENT is a symlink), so
    # `-L` on it is false and the naive check above treats it as a foreign
    # file to move aside. Moving it deletes the file from the repository.
    #
    # Resolve the parent and refuse to touch anything living inside DOTFILES.
    real_parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || continue
    if [[ "$real_parent" == "$DOTFILES" || "$real_parent" == "$DOTFILES"/* ]]; then
      continue
    fi

    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$target" "$BACKUP_DIR/$rel"
    info "backed up ~/$rel"
    backed_up_any=true
  done < <(cd "$DOTFILES/$pkg" && find . -type f -print | sed 's|^\./||')

  if stow --target="$HOME" --dir="$DOTFILES" --restow "$pkg" 2>&1; then
    ok "linked $pkg"
  else
    STOW_FAILED+=("$pkg")
    warn "could not link '$pkg' — continuing."
  fi
done

$backed_up_any && warn "pre-existing files were moved to $BACKUP_DIR"

# Ghostty reads BOTH ~/.config/ghostty/config and the macOS-native
# ~/Library/Application Support/com.mitchellh.ghostty/config, and the latter
# WINS. Ghostty writes it whenever settings are changed in its GUI, so a new
# machine can end up with a file there that silently shadows everything stowed
# — the config looks correctly linked and simply has no effect.
#
# Verified by planting `font-size = 99` there: `ghostty +show-config` reported
# 99 and ignored the stowed 18.
GHOSTTY_APPSUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [[ -f "$GHOSTTY_APPSUPPORT" && ! -L "$GHOSTTY_APPSUPPORT" ]]; then
  # A file of only whitespace shadows nothing; leave it alone.
  if [[ -s "$GHOSTTY_APPSUPPORT" ]] && grep -qE '[^[:space:]]' "$GHOSTTY_APPSUPPORT"; then
    mkdir -p "$BACKUP_DIR"
    mv "$GHOSTTY_APPSUPPORT" "$BACKUP_DIR/ghostty-application-support-config"
    warn "moved a shadowing Ghostty config out of Application Support"
    warn "  (it overrides ~/.config/ghostty/config; saved in $BACKUP_DIR)"
  fi
fi

# =========================================================================
# Phase 5 — zsh + oh-my-zsh
# =========================================================================
phase "Phase 5/7  Shell"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  # KEEP_ZSHRC=yes protects the symlink phase 4 just created.
  # RUNZSH=no stops the installer dropping us into a subshell.
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "oh-my-zsh installed"
else
  ok "oh-my-zsh already present"
fi

# Guard against a future installer change clobbering the link anyway.
if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  warn "~/.zshrc is a real file, not the stow link — oh-my-zsh replaced it."
  mkdir -p "$BACKUP_DIR"
  mv "$HOME/.zshrc" "$BACKUP_DIR/.zshrc.oh-my-zsh-template"
  stow --target="$HOME" --dir="$DOTFILES" --restow zshrc && ok "re-linked zshrc"
fi

# The custom plugins .zshrc loads. These are NOT bundled with oh-my-zsh and
# are the reason a fresh machine previously errored on every prompt.
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM_DIR/plugins"

clone_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM_DIR/plugins/$1"
  if [[ -d "$dest" ]]; then
    ok "$name already present"
  else
    info "Cloning $name..."
    git clone --depth=1 "$url" "$dest"
    ok "$name installed"
  fi
}

clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting

# Default shell. macOS ships zsh, but we want the Homebrew build that .zshrc
# and the PATH export assume.
BREW_ZSH="$BREW_PREFIX/bin/zsh"
if [[ -x "$BREW_ZSH" ]]; then
  if [[ "${SHELL:-}" == "$BREW_ZSH" ]]; then
    ok "default shell already $BREW_ZSH"
  else
    grep -qxF "$BREW_ZSH" /etc/shells || echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null
    chsh -s "$BREW_ZSH" && ok "default shell set to $BREW_ZSH"
  fi
fi

# =========================================================================
# Phase 6 — macOS defaults
# =========================================================================
phase "Phase 6/7  macOS defaults"

if $SKIP_MACOS; then
  info "skipped (--skip-macos)"
else
  bash "$DOTFILES/lib/macos-defaults.sh"
fi

# =========================================================================
# Phase 7 — identity
# =========================================================================
phase "Phase 7/7  Identity"

if $SKIP_IDENTITY; then
  info "skipped (--skip-identity)"
else
  bash "$DOTFILES/lib/identity.sh"
fi

# =========================================================================
if [[ ${#FAILED_TIERS[@]} -gt 0 || ${#STOW_FAILED[@]} -gt 0 || ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  phase "Done — with failures"
else
  phase "Done"
fi

cat <<EOF
    Restart your terminal, or: exec zsh

    Manual steps this script cannot do:
      - Grant Accessibility permission to Karabiner-Elements and Raycast
        (System Settings > Privacy & Security > Accessibility)
      - Sign into Bitwarden, then the apps whose licences it holds
      - Import Raycast settings (Raycast > Settings > Advanced > Import)

    Verify with: $DOTFILES/scripts/healthcheck.sh
EOF

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  printf '\n'
  warn "these individual packages could not be installed:"
  for p in "${FAILED_PACKAGES[@]}"; do
    warn "    ${p%%:*} tier -> ${p#*:}"
  done
  warn "everything else in those tiers DID install."
  warn "a package removed upstream should be deleted from its Brewfile;"
  warn "an untrusted third-party cask needs: brew trust --tap <tap>"
elif [[ ${#FAILED_TIERS[@]} -gt 0 ]]; then
  printf '\n'
  warn "these tiers had failures: ${FAILED_TIERS[*]}"
  warn "retry with: brew bundle --file=brew/Brewfile.<tier>"
fi

if [[ ${#STOW_FAILED[@]} -gt 0 ]]; then
  printf '\n'
  warn "these packages could not be linked: ${STOW_FAILED[*]}"
  warn "your configs for them are NOT active. Inspect with:"
  warn "  stow --no --verbose --target=\"\$HOME\" --dir=\"$DOTFILES\" <package>"
fi

if [[ ${#FAILED_TIERS[@]} -gt 0 || ${#STOW_FAILED[@]} -gt 0 || ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  exit 1
fi
