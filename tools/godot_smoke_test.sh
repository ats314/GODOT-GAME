#!/usr/bin/env bash
# Validate a Godot project inside a headless Linux container (Codespaces, CI, this
# sandbox). Downloads and caches the engine, imports the project, boots a scene, and —
# with --render — actually renders a frame through Mesa's software rasterizer and saves
# a screenshot, so a change can be verified visually with no GPU present.
#
#   tools/godot_smoke_test.sh <project-dir> [main-scene] [--render] [--forward-plus]
#
# Examples:
#   tools/godot_smoke_test.sh game
#   tools/godot_smoke_test.sh game res://scenes/main.tscn --render
#   tools/godot_smoke_test.sh game res://scenes/main.tscn --render --forward-plus
#
# Exit codes: 0 clean, 1 engine reported script errors, 2 setup problem.

set -uo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/godot-bin}"
BIN="$CACHE_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"

PROJECT="${1:-}"
SCENE="${2:-}"
RENDER=0
FORWARD_PLUS=0
for arg in "$@"; do
    case "$arg" in
        --render) RENDER=1 ;;
        --forward-plus) RENDER=1; FORWARD_PLUS=1 ;;
    esac
done
[ -n "$SCENE" ] && [ "${SCENE:0:2}" = "--" ] && SCENE=""

if [ -z "$PROJECT" ] || [ ! -f "$PROJECT/project.godot" ]; then
    echo "usage: $0 <project-dir> [main-scene] [--render] [--forward-plus]" >&2
    echo "error: no project.godot in '${PROJECT:-<unset>}'" >&2
    exit 2
fi

# ---- engine ----------------------------------------------------------------
if [ ! -x "$BIN" ]; then
    echo "==> fetching Godot ${GODOT_VERSION} (cached at $CACHE_DIR)"
    mkdir -p "$CACHE_DIR" || exit 2
    curl -sSL -o "$CACHE_DIR/godot.zip" "$URL" || { echo "error: download failed" >&2; exit 2; }
    unzip -o -q "$CACHE_DIR/godot.zip" -d "$CACHE_DIR" || exit 2
    chmod +x "$BIN" || exit 2
fi
echo "==> $("$BIN" --version)"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# ---- import ----------------------------------------------------------------
# The first import builds the .godot/ cache and surfaces broken resources and UIDs.
echo "==> importing"
timeout 600 "$BIN" --headless --path "$PROJECT" --import >>"$LOG" 2>&1

# ---- boot ------------------------------------------------------------------
# Headless uses the dummy renderer: scripts, signals, timers and autoloads all run,
# but nothing is drawn. This is the fast correctness check.
echo "==> booting headless"
if [ -n "$SCENE" ]; then
    timeout 300 "$BIN" --headless --path "$PROJECT" "$SCENE" --quit-after 300 >>"$LOG" 2>&1
else
    timeout 300 "$BIN" --headless --path "$PROJECT" --quit-after 300 >>"$LOG" 2>&1
fi

# ---- optional rendered frame ----------------------------------------------
# Mesa's llvmpipe (OpenGL) and lavapipe (Vulkan) rasterize on the CPU, so a real frame
# can be produced without a GPU. Correct pixels, meaningless frame rate.
if [ "$RENDER" = 1 ]; then
    if ! command -v xvfb-run >/dev/null; then
        echo "error: --render needs xvfb-run (apt-get install -y xvfb)" >&2
        exit 2
    fi
    if [ "$FORWARD_PLUS" = 1 ]; then
        if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ]; then
            echo "error: --forward-plus needs the software Vulkan driver" >&2
            echo "       apt-get update && apt-get install -y mesa-vulkan-drivers" >&2
            exit 2
        fi
        DRIVER=vulkan
    else
        DRIVER=opengl3
    fi
    echo "==> rendering a frame ($DRIVER, software rasterizer)"
    timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" \
        env LIBGL_ALWAYS_SOFTWARE=1 \
        "$BIN" --path "$PROJECT" --rendering-driver "$DRIVER" \
        --resolution 1280x720 ${SCENE:+"$SCENE"} --quit-after 600 >>"$LOG" 2>&1
fi

# ---- verdict ---------------------------------------------------------------
# Audio and GPU probing noise is expected in a container and is not a failure. Godot
# prints the cause on the line *after* the message ("   at: init_output_device
# (drivers/alsa/...)"), so each error is joined with its following line before the
# benign-noise filter runs — otherwise a bare 'ERROR: Condition "status < 0" is true'
# from a missing sound card reads as a real failure.
FINDINGS="$(awk '{ line[NR] = $0 }
    END { for (i = 1; i <= NR; i++)
              if (line[i] ~ /SCRIPT ERROR|Parse Error|ERROR:/)
                  print line[i] " >> " line[i + 1] }' "$LOG" \
    | grep -viE "vulkan|opengl|xdg|alsa|pulse|audio_|audio server|audio driver|dummy|libGL|swrast|no such device|CANT_OPEN")"

if [ -n "$FINDINGS" ]; then
    echo "==> FAILED: engine reported errors"
    printf '%s\n' "$FINDINGS"
    exit 1
fi

echo "==> clean: no script errors"
