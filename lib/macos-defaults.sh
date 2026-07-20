#!/usr/bin/env bash
#
# macOS system defaults.
#
# Every value here was read off the existing machine with `defaults read`, not
# copied from a template. Settings that already matched the macOS default are
# deliberately NOT written — see the note at the bottom.
#
# Safe to re-run: `defaults write` is idempotent by nature.

set -euo pipefail

echo "==> Applying macOS defaults"

# --- Keyboard ------------------------------------------------------------
# Fast key repeat. KeyRepeat=2 is well below the slowest UI-exposed setting;
# System Settings cannot produce this value with the slider.
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 25

# Hold a key to repeat it rather than opening the accent picker. Required for
# comfortable hjkl navigation in nvim.
defaults write -g ApplePressAndHoldEnabled -bool false

# --- Appearance ----------------------------------------------------------
defaults write -g AppleInterfaceStyle -string "Dark"

# --- Dock ----------------------------------------------------------------
defaults write com.apple.dock orientation -string "left"   # dock on the left edge
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0     # reveal with no delay
defaults write com.apple.dock tilesize -int 128
defaults write com.apple.dock magnification -bool false

# Keep Spaces in a fixed order instead of reordering by recent use.
defaults write com.apple.dock mru-spaces -bool false

# Hot corners. 2 = Mission Control, 1 = disabled. Modifier 0 = no modifier key.
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 0

# --- Stage Manager -------------------------------------------------------
defaults write com.apple.WindowManager GloballyEnabled -bool false

# --- Trackpad ------------------------------------------------------------
defaults write -g com.apple.trackpad.scaling -float 2.5    # tracking speed

# --- Menu bar clock ------------------------------------------------------
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true

# --- Finder --------------------------------------------------------------
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search current folder
defaults write com.apple.finder NewWindowTarget -string "PfDo"        # new windows -> Documents

# --- Spotlight keyboard shortcuts ---------------------------------------
# Free Cmd+Space for Raycast by disabling Spotlight's claim on it.
#
#   64 = "Show Spotlight search"        Cmd+Space
#   65 = "Show Finder search window"    Cmd+Option+Space
#
# These live in a nested plist structure that `defaults write` cannot reach
# with a simple key/value, hence -dict-add with an inline plist. The
# parameters array is [ascii, keycode, modifiers]: 32 = space character,
# 49 = space keycode, 1048576 = Cmd, 1572864 = Cmd+Option. The key/modifier
# values are preserved exactly so the shortcut can be re-enabled in System
# Settings without it appearing as "none".
disable_hotkey() {
  local id="$1" mods="$2"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" "
    <dict>
      <key>enabled</key><false/>
      <key>value</key><dict>
        <key>type</key><string>standard</string>
        <key>parameters</key>
        <array>
          <integer>32</integer>
          <integer>49</integer>
          <integer>$mods</integer>
        </array>
      </dict>
    </dict>"
}
disable_hotkey 64 1048576   # Cmd+Space
disable_hotkey 65 1572864   # Cmd+Option+Space

# Apply symbolichotkeys without requiring a logout. Best-effort: this private
# helper is not guaranteed to exist on every macOS release.
ACTIVATE="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
[[ -x "$ACTIVATE" ]] && "$ACTIVATE" -u >/dev/null 2>&1 || true

# --- Restart affected apps ----------------------------------------------
# Dock and Finder cache these; without a restart the changes appear only
# after the next login.
for app in Dock Finder; do
  killall "$app" >/dev/null 2>&1 || true
done

echo "    done. Some keyboard settings apply only to newly launched apps."

# -------------------------------------------------------------------------
# Deliberately NOT written, because the current machine already matches the
# macOS default and writing them would be noise:
#
#   com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking  (= 0)
#   com.apple.screencapture location / type / disable-shadow     (unset)
#   -g com.apple.swipescrolldirection                            (unset)
#   com.apple.finder AppleShowAllExtensions / AppleShowAllFiles  (unset)
#
# If you later want tap-to-click or a custom screenshot folder, add them here
# rather than clicking through System Settings.
# -------------------------------------------------------------------------
