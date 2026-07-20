# dotfiles

macOS configuration, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## New machine

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --all
```

`bootstrap.sh` is idempotent — re-running a finished bootstrap is a no-op.
It never overwrites an existing file: anything in the way of a symlink is
moved to `~/.dotfiles-backup/<timestamp>/` first.

### Tiers

Running with no arguments installs **core** only, which is the fastest path
to a usable machine.

| Tier | Contents | Command |
|---|---|---|
| `core` | shell, CLI, editor, terminal, desktop essentials, fonts | *(default)* |
| `dev` | runtimes, databases, editors, cloud, API tools | `--with dev` |
| `apps` | browsers, communication, productivity | `--with apps` |
| `media` | audio, video, images, documents | `--with media` |
| `ai` | assistants, coding agents, meeting tools | `--with ai` |
| `mas` | Mac App Store apps (needs an App Store login) | `--with mas` |

```sh
./bootstrap.sh                    # core only
./bootstrap.sh --with dev,apps    # core + dev + apps
./bootstrap.sh --all              # everything
./bootstrap.sh --help
```

Other flags: `--skip-macos`, `--skip-identity`.

### Phases

1. **Preflight** — macOS + architecture check, Xcode CLT, sudo keepalive
2. **Homebrew** — install if absent, put `brew` on PATH for this session
3. **Packages** — taps first, then core, then any selected tiers
4. **Shell** — oh-my-zsh, its two custom plugins, default shell
5. **Stow** — link every package, backing up conflicts
6. **macOS defaults** — `lib/macos-defaults.sh`
7. **Identity** — `lib/identity.sh` (interactive)

## Verify

```sh
./scripts/healthcheck.sh
```

Read-only. Checks commands, oh-my-zsh plugins, every symlink, git identity,
and the macOS defaults. Exits non-zero on any failure.

## Layout

```
bootstrap.sh          entry point
brew/                 Brewfile per tier
lib/                  macos-defaults.sh, identity.sh
scripts/              healthcheck.sh
docs/superpowers/specs/   design docs
<package>/            stow packages, each mirroring $HOME
```

### Stow packages

`alacritty` `claude` `ghostty` `git` `karabiner` `nvim` `tmux` `zshrc`

Each mirrors its path relative to `$HOME`. `zshrc/.zshrc` links to
`~/.zshrc`; `nvim/.config/nvim` links to `~/.config/nvim`.

Add a package:

```sh
mkdir -p newthing/.config/newthing
mv ~/.config/newthing/* newthing/.config/newthing/
stow --target="$HOME" newthing
```

Then add it to `STOW_PACKAGES` in `bootstrap.sh`.

## Git identity

`~/.gitconfig` is a symlink into this repo, so **identity is not stored here**
— `git config --global user.email ...` would commit your address.

Shared settings live in `git/.gitconfig` (tracked). Identity lives in
`~/.gitconfig.local` (untracked), pulled in via `[include]`. `lib/identity.sh`
creates it.

## Manual steps

Not scriptable:

- **MonoLisa Nerd Font.** `ghostty/.config/ghostty/config` sets
  `font-family = MonoLisa Nerd Font`. MonoLisa is a commercial, licensed font —
  it is not on Homebrew and is deliberately **not** committed here, since this
  repo is public and redistributing it would breach the licence. Copy
  `~/Library/Fonts/MonoLisaNerdFont-Regular.ttf` across from a machine that has
  it. Without it Ghostty silently falls back to a system default, which looks
  exactly like the config having failed to load. `healthcheck.sh` checks for it.
- Accessibility permission for Karabiner-Elements and Raycast
  (System Settings → Privacy & Security → Accessibility)
- App Store login, required before the `mas` tier installs anything
- Bitwarden unlock, then the apps whose licences it holds
- Raycast settings import (Raycast → Settings → Advanced → Import)

## Notes

- **Apple Silicon assumed.** `.zshrc` hardcodes `/opt/homebrew` in `PATH` and
  the nvm source lines. Bootstrap warns on Intel but does not rewrite them.
- **yabai/skhd were removed** (2026-07). Installed but never running; window
  management moved to Raycast + alt-tab. Recover from git history if needed.
- **`zmk-config-totem/`** is a separate keyboard-firmware checkout with its
  own `.git`, and is gitignored here.
