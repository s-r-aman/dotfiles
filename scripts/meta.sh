#!/bin/bash
echo "⬇️ INSTALLING SKHD"
brew install koekeishiya/formulae/skhd

echo "▶️ STARTING SKHD"
brew services start skhd
