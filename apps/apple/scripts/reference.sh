#!/bin/sh
# Shoot the reference screenshots other builds match against, and write their README.
#   apps/apple/scripts/reference.sh            Debug build of the beta, then every shot
# Shots go to docs/images/reference/. Re-run whenever a scene changes (TODO.md, from @linux).
set -eu
cd "$(dirname "$0")/../../.."

OUT=docs/images/reference
APP="apps/apple/.build-app/Build/Products/Debug/Noddy Yookerspiel.app/Contents/MacOS/Noddy Yookerspiel"
(cd apps/apple && xcodegen generate --quiet)
xcodebuild -quiet -project apps/apple/CribMaze.xcodeproj -scheme CribMazeBeta -configuration Debug \
  -derivedDataPath apps/apple/.build-app -skipPackageUpdates build
mkdir -p "$OUT"
rm -f "$OUT"/*.png
VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' apps/apple/project.yml)
SPEC=$(sed -n 's/.*"specVersion": \([0-9]*\).*/\1/p' cribbage/minigames/spec.json)

# name|flags|what it shows. Every shot is seed 1, turn 1, unless its flags say otherwise.
# The breakdown set g32,g33,c3,h2 is A♥ 7♦ 6♦ A♦: a fifteen, a pair and two edge cards.
SHOTS='deal|--deal|The deal: the bot'"'"'s backs, your six cards, the empty crib slots
deal-picked|--deal --pick 3S,QD|The deal with two cards picked
deal-hint|--deal --hint|The deal with the discard hint showing
turn||The match turn as it starts
turn-toast|--toast|A prize toast over the board (the blank card'"'"'s +5 steps)
trace|--select g00,g01|Tracing two cards that make no combo
trace-combo|--select g02,g03|A combo lighting while tracing (8♥ 7♣, a fifteen)
armed-bomb|--arm bomb|A bomb armed, waiting for its target
pop|--pop g02,g03|A scored set mid-pop, with the breakdown off
pop-bomb|--pop g00 --bomb|A bombed card mid-pop
breakdown-1|--breakdown g32,g33,c3,h2 --stage 1|Breakdown, cue sheet order 1: the breakdown starts and the board dims
breakdown-2|--breakdown g32,g33,c3,h2 --stage 2|Order 2: the cards are up in the row
breakdown-3|--breakdown g32,g33,c3,h2 --stage 3|Order 3: the banner is in
breakdown-4|--breakdown g32,g33,c3,h2 --stage 4|Orders 4 and 6: the tally is in and the first combo (the fifteen) is lit
breakdown-5|--breakdown g32,g33,c3,h2 --stage 5|Order 6: the fifteen unlit, before the next combo
breakdown-6|--breakdown g32,g33,c3,h2 --stage 6|Order 6: the second combo (the pair) lit
breakdown-7|--breakdown g32,g33,c3,h2 --stage 7|Order 6: the pair unlit
breakdown-8|--breakdown g32,g33,c3,h2 --stage 8|Order 12: power up, the edge cards lit with their new chips
breakdown-9|--breakdown g32,g33,c3,h2 --stage 9|Order 13: the total line
breakdown-hold|--breakdown g32,g33,c3,h2|Order 14: the hold, waiting for a tap
warning|--trace g02,g03,g13|The left-over warning (8♥ 7♣ J♠: the J is left over)
info-hand|--info hand|Info card: the hand
info-crib|--info crib|Info card: the crib
info-starter|--info starter|Info card: the starter
info-tray|--info tray|Info card: the power jokers
info-counter|--info counter|Info card: the card counter
summary|--end|The turn summary
settings|--settings|The settings panel, Game tab (drawn on its own: it is a popover over the footer)'

{
  echo "# Reference screenshots"
  echo
  echo "What the Mac beta (Noddy Yookerspiel) shows, for other builds to match shot for shot. Made by \`apps/apple/scripts/reference.sh\` from Apple build $VERSION, spec $SPEC; re-shoot when a scene changes."
  echo
  echo "- Each phone shot is the 402 pt wide phone with 24 pt of page around it, rendered at 2x (900 px wide). The settings shot is the 340 × 620 pt panel at the Mac's screen scale (2x)."
  echo "- Every shot is a still from \`--snapshot\`, the beta's own renderer: \`\"Noddy Yookerspiel\" --snapshot <file> --seed 1 <flags>\`. Animations are at their end state, so motion isn't shown; ui.md › Motion and \`config/fx.json\` give the timings."
  echo "- Toasts are hidden unless a shot asks for one. The beta uses the system font; Crib Maze, and the beta with \`--saira\`, use Saira Semi Condensed (ui.md › Type)."
  echo "- Where the app and ui.md disagree, follow ui.md: \`BUGS.md\` › Open and ui.md › Gaps list what the app gets wrong, and the shots show those bugs too."
  echo
  echo "| Shot | Flags | Shows |"
  echo "|---|---|---|"
} > "$OUT/README.md"

echo "$SHOTS" | while IFS='|' read -r name flags what; do
  # shellcheck disable=SC2086
  "$APP" --snapshot "$PWD/$OUT/$name.png" --seed 1 $flags
  [ -f "$OUT/$name.png" ] || { echo "No shot for $name" >&2; exit 1; }
  echo "| [$name]($name.png) | \`--seed 1${flags:+ $flags}\` | $what |" >> "$OUT/README.md"
done
echo "Wrote $(ls "$OUT"/*.png | wc -l | tr -d ' ') shots to $OUT"
