# New-Mac Bootstrap — Design

**Date:** 2026-07-20
**Status:** Approved for planning
**Goal:** Reproduce this Mac's environment on a new Mac from a `git clone` plus one command.

---

## 1. Current state

### What works

The repo is a **GNU Stow** layout and stow is genuinely in use. Every target in `$HOME` is a
live symlink into `~/dotfiles`, verified by `readlink`:

| Link | Target |
|---|---|
| `~/.zshrc` | `dotfiles/zshrc/.zshrc` |
| `~/.tmux.conf` | `dotfiles/tmux/.tmux.conf` |
| `~/.config/karabiner` | `../dotfiles/karabiner/.config/karabiner` |
| `~/.config/nvim` | `../dotfiles/nvim/.config/nvim` |
| `~/.config/ghostty` | `../dotfiles/ghostty/.config/ghostty` |
| `~/.config/yabai` | `../dotfiles/yabai/.config/yabai` |
| `~/.config/skhd` | `../dotfiles/skhd/.config/skhd` |
| `~/.config/alacritty` | `../dotfiles/alacritty/.config/alacritty` |
| `~/.claude/commands` | `../dotfiles/claude/.claude/commands` |

**9 stow packages:** `alacritty claude ghostty karabiner nvim skhd tmux yabai zshrc`
(`scripts/` is not a stow package; `zmk-config-totem/` is gitignored with its own `.git`.)

The linking layer is sound and is **not** being replaced.

### What is broken

`scripts/` has drifted far from reality:

| | scripts install | actually installed |
|---|---|---|
| brew formulae | 13 | 48 top-level (184 incl. deps) |
| casks | 15 | 73 |
| Mac App Store | 4 | 23 |

Roughly **110 packages in daily use would be absent** on a new Mac. Specific defects, each verified:

1. **Broken shell on first launch.** `.zshrc` loads `zsh-autosuggestions` and
   `zsh-syntax-highlighting`. These are oh-my-zsh *custom* plugins requiring `git clone` into
   `$ZSH_CUSTOM/plugins/`. They exist on this machine (hand-installed) but no script creates
   them — a new Mac errors on every prompt.
2. **`exa` vs `eza`.** `cli-utils.sh` installs `exa` (unmaintained). `.zshrc` aliases
   `lsa`/`lla`/`ll` all invoke `eza`. Confirmed: `which exa` → not found, `eza` → present.
   All three aliases break.
3. **`zoxide` never installed.** `.zshrc` runs `eval "$(zoxide init zsh)"`; zoxide appears in
   no script.
4. **Typo swallows Dropover.** `utilities.sh` line reads `mas insall 1355679052`. The `drop()`
   shell function then silently no-ops.
5. **Dead package.** `utilities.sh` installs cask `fig` — a discontinued product that is not
   installed on this machine at all.
6. **Superseded package.** `logitech-options` (10.26.49) vs current `logi-options+` (2.1.854976).
7. **Redundant casks.** `brew info` resolution proves three pairs are the same cask:
   `docker` → `docker-desktop`, `handbrake` → `handbrake-app`, `google-cloud-sdk` → `gcloud-cli`.
   All three pairs are currently installed.
8. **Duplicate OpenIn.** Installed both as cask `openin` and MAS app `1547147101`.
9. **No orchestration.** Six scripts must be run by hand in the right order, and **none of them
   runs `stow`** — the one step that applies the configs.
10. **No Brewfile**, no Homebrew bootstrap, no macOS defaults, no `.gitconfig` in the repo
    despite `~/.config/git` existing.

### Uncommitted work (blocks cloning)

- `claude/` is **untracked** — `/grade` and `/split-expenses` commands would be lost.
- `karabiner/.config/karabiner/karabiner.json` has uncommitted edits.
- `.gitignore` and `scripts/setup-terminal.sh` modified.

Committing these is **phase 0 of the plan**, not an afterthought.

---

## 2. Approach

**Brewfile + phased `bootstrap.sh`.** Rejected alternatives:

- *Makefile front-end* — reasonable, but an extra layer over what is a linear script.
- *chezmoi / nix-darwin* — full migration off a stow setup that demonstrably works, with a long
  learning curve. Wrong trade for "make the new Mac usable."

---

## 3. Tier layout

All 48 top-level formulae are assigned (19 + 18 + 11). The 73 installed casks dedupe to **70**
(three alias pairs collapse, see §1 defect 7); all 70 are assigned. The 23 MAS apps become 22
(`openin` dropped as a cask duplicate). Every removal is deliberate and listed in §6 — nothing
is dropped silently.

```
brew/
├── Brewfile.taps     # 9 third-party taps — MUST be bundled first
├── Brewfile.core     # 19 formulae + 11 casks + 5 fonts
├── Brewfile.dev      # 18 formulae + 13 casks
├── Brewfile.apps     # 22 casks
├── Brewfile.media    # 11 formulae +  8 casks
├── Brewfile.ai       # 11 casks
└── Brewfile.mas      # 22 MAS apps
```

Cask total: 11 + 5 + 13 + 22 + 8 + 11 = **70**.

**taps** — `kamillobinski/thock` (→ `thock`), `muesli-hq/muesli` (→ `muesli`),
`xykong/tap` (→ `flux-markdown`). Bundled before every other tier.

> **Corrected 2026-07-20 after a real failure on the target Mac.** This originally
> mirrored all nine taps from the source machine. Six were wrong: `homebrew/services`
> and `homebrew/cask-fonts` are deprecated and now empty, and *tapping a deprecated
> repo is a hard error* that aborted `brew bundle` at phase 3. `asmvik/formulae`
> supplied yabai/skhd (dropped); `theboredteam/boring-notch`, `oven-sh/bun` and
> `bbc/audiowaveform` supply nothing these Brewfiles reference. Every font cask now
> resolves from `homebrew/cask`, and `brew services` is built into brew.
>
> Lesson: mirroring a machine's tap list is not the same as validating it. Taps must
> be derived from what the Brewfiles actually reference.

**core** — usable machine: `zsh stow starship zoxide fzf eza bat fd jq neovim tmux gh thefuck
trash mas lazygit yazi btop pinentry-mac`; casks `ghostty karabiner-elements raycast
alt-tab shottr itsycal betterdisplay monitorcontrol dockdoor openin bitwarden`; fonts
`font-hack-nerd-font font-ibm-plex-mono font-karla font-symbols-only-nerd-font font-fontawesome`.

**yabai/skhd are deliberately excluded.** They are installed on the current machine but neither
service runs; window management has moved to Raycast + alt-tab. The `yabai/` and `skhd/` stow
packages are removed from the repo as part of this work (recoverable from git history).

**dev** — `nvm pyenv uv docker redis act killport bitwarden-cli jless fx glow mdcat rename duti
herdr jupyterlab tectonic typst`; casks `visual-studio-code cursor zed sublime-text
docker-desktop postman ngrok beekeeper-studio mongodb-compass pgadmin4 gcloud-cli wireshark-app
applite`.

**apps** — browsers (`arc brave-browser firefox google-chrome zen thebrowsercompany-dia`),
comms (`slack telegram whatsapp zoom loom`), productivity (`notion obsidian raindropio anki
antinote flux-markdown muesli`), hardware/net (`logi-options+ thock surfshark alacritty`).

**media** — `ffmpeg imagemagick yt-dlp youtube-dl sox sevenzip poppler ghostscript kepubify
fontforge spotify_player`; casks `iina spotify handbrake-app audacity descript eqmac soundsource
qbittorrent`.

**ai** — `claude chatgpt chatgpt-atlas codex cmux conductor supacode granola fathom fluidvoice
finetune`. Isolated because it churns fastest; a stale entry here must not block a bootstrap.

**mas** — 22 IDs (all 23 current, less `openin` `1547147101` which duplicates the cask).

`bootstrap.sh` installs **core** by default. `--with dev,apps` adds tiers; `--all` installs everything.

---

## 4. Bootstrap phases

Ordered; each independently idempotent and safe to re-run.

| # | Phase | Behaviour |
|---|---|---|
| 1 | Preflight | Xcode CLT, arch check, sudo keepalive |
| 2 | Homebrew | Install if absent; `eval "$(brew shellenv)"` into current session |
| 3 | Brew bundle | `Brewfile.taps` first, then `brew bundle --file` per selected tier |
| 4 | oh-my-zsh | Framework **+ the two missing custom plugins** (fixes defect 1) |
| 5 | Stow | `stow -R` all packages, detecting conflicts rather than failing blind |
| 6 | macOS defaults | Values captured from this machine (§5) |
| 7 | Identity | Interactive: SSH keygen, git identity, `gh auth login`, Bitwarden unlock |

There is no services phase. `redis` is the only running brew service on the current machine and
starting it is a per-project choice, left manual.

**Idempotency rule:** every phase checks before it acts. Re-running a completed bootstrap must
be a no-op that exits 0.

**Resilience rule:** package sources rot — taps get deprecated, casks get renamed or pulled.
No single `brew bundle` failure may abort the run and leave the machine half-configured. Every
bundle call is allowed to fail; failures are collected, reported by name at the end, and
reflected in a non-zero exit.

**bash 3.2 constraint:** `/usr/bin/env bash` on macOS resolves to bash 3.2.57, not 5.x. Two
idioms that work in modern bash are fatal there under `set -u`, and both were present in the
first implementation:
- expanding an empty array — `"${ARR[@]}"` raises *unbound variable*; use
  `${ARR[@]+"${ARR[@]}"}` or guard on `${#ARR[@]}`
- `local a="$1" b="$a"` — `local` declares every name before assigning, so `$a` is unset while
  `b` expands; split into separate `local` statements

**Explicitly out of scope:** app preference plists (Raycast/Shottr/alt-tab). They carry
machine-specific and licence state and are overwritten on app quit — unreliable to sync.

---

## 5. macOS defaults

Read from this machine, not a generic template.

| Domain | Key | Value | Why |
|---|---|---|---|
| `-g` | `KeyRepeat` | `2` | Fast repeat |
| `-g` | `InitialKeyRepeat` | `25` | Short delay before repeat |
| `-g` | `ApplePressAndHoldEnabled` | `0` | Key-repeat over accent popup (vim) |
| `-g` | `AppleInterfaceStyle` | `Dark` | Dark mode |
| `com.apple.dock` | `autohide` | `1` | |
| `com.apple.dock` | `autohide-delay` | `0` | No reveal delay |
| `com.apple.dock` | `tilesize` | `128` | |
| `com.apple.dock` | `mru-spaces` | `0` | Spaces keep fixed order (personal preference) |
| `com.apple.finder` | `ShowPathbar` | `1` | |
| `com.apple.finder` | `ShowStatusBar` | `1` | |
| `com.apple.finder` | `FXPreferredViewStyle` | `Nlsv` | List view |
| `com.apple.finder` | `FXDefaultSearchScope` | `SCcf` | Search current folder |

Trackpad `Clicking` is `0` and all screenshot keys are unset — both already match the system
default, so they are read-only observations and are **not** written by `defaults.sh`.

---

## 6. Fixes folded in

- `exa` → `eza`
- add missing `zoxide`
- fix `mas insall` → `mas install`
- drop `fig`
- `logitech-options` → `logi-options+`
- collapse `docker`/`handbrake`/`google-cloud-sdk` alias pairs to canonical names
- drop duplicate `openin` MAS entry
- add `git/` as a new stow package carrying `.gitconfig`
- remove `yabai/` and `skhd/` stow packages
- commit `claude/` and pending karabiner edits

Net stow packages: **8** — `alacritty claude ghostty git karabiner nvim tmux zshrc`.

---

## 7. Success criteria

On a clean Mac, `git clone <repo> ~/dotfiles && ~/dotfiles/bootstrap.sh --all`:

1. completes without manual intervention up to the identity phase;
2. yields a new shell with **no errors** and working `ll`/`lsa`/`z`/`starship`;
3. leaves all 8 stow packages symlinked;
4. installs every third-party-tapped cask (`thock`, `muesli`) without resolution failure;
5. reproduces the §5 defaults;
6. is a clean no-op when re-run.
