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
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0     # reveal with no delay
defaults write com.apple.dock tilesize -int 128

# Keep Spaces in a fixed order instead of reordering by recent use.
defaults write com.apple.dock mru-spaces -bool false

# --- Finder --------------------------------------------------------------
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search current folder

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
