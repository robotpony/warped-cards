#!/bin/sh
# Adds Crib RPG to this user's app launcher: a .desktop entry that runs scripts/run.sh from this
# checkout, and the icons from design/icon/export/linux in the hicolor theme (design/icon/README.md).
# Writes only under ~/.local/share. Run it again after moving the checkout.
set -eu
APP="$(cd "$(dirname "$0")/.." && pwd)"
ICONS="$APP/../../design/icon/export/linux"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
for n in 16 32 48 64 128 256 512; do
  mkdir -p "$DATA/icons/hicolor/${n}x${n}/apps"
  cp "$ICONS/crib-rpg-$n.png" "$DATA/icons/hicolor/${n}x${n}/apps/crib-rpg.png"
done
mkdir -p "$DATA/icons/hicolor/scalable/apps" "$DATA/applications"
cp "$ICONS/crib-rpg.svg" "$DATA/icons/hicolor/scalable/apps/crib-rpg.svg"
cat > "$DATA/applications/crib-rpg.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Crib RPG
Comment=Cribbage with jokers, on a scoring grid
Exec=$APP/scripts/run.sh
Icon=crib-rpg
Terminal=false
Categories=Game;CardGame;
StartupWMClass=Crib RPG
DESKTOP
echo "Installed $DATA/applications/crib-rpg.desktop"
