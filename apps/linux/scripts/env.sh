# Shared by the Linux scripts: where things are, and which Godot to run.
# Set GODOT to the Godot 4.7 editor binary, or put `godot` on PATH (apps/linux/README.md).
LINUX_APP="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || true)}"
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "Godot 4.7 not found: set GODOT or put godot on PATH (apps/linux/README.md)" >&2
  exit 1
fi
# Swift's crash handler would take over crash reports for all of Godot; let Godot report its own.
export SWIFT_BACKTRACE=enable=no
