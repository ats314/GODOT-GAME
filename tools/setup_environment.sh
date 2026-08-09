#!/usr/bin/env bash
# Make a fresh Linux container able to build, run, render and lint a Godot 4.7 project.
#
# One script, two callers: the Codespaces devcontainer (.devcontainer/devcontainer.json)
# and the Claude Code web session hook (.claude/hooks/session-start.sh). Keeping it in
# one place means a Codespace and an agent session cannot drift apart in what they can do.
#
#   tools/setup_environment.sh            install everything, then report
#   tools/setup_environment.sh --verify   report only, install nothing
#
# Idempotent and non-interactive: safe to run on every session start. Re-runs are fast
# because each step checks before doing anything.

set -uo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/godot-bin}"
GODOT_BIN="$CACHE_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"

VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && VERIFY_ONLY=1

# Codespaces runs as a non-root user; this sandbox runs as root. Handle both.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null && SUDO="sudo" || {
        echo "warning: not root and no sudo — apt packages will be skipped" >&2
    }
fi

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- apt packages
# xvfb provides the virtual display; mesa-vulkan-drivers provides lavapipe, the
# software Vulkan driver that makes Forward+ and Mobile testable without a GPU.
# Without lavapipe, Godot silently falls back to OpenGL when asked for Vulkan.
install_apt() {
    local missing=()
    have xvfb-run || missing+=("xvfb")
    [ -f /usr/share/vulkan/icd.d/lvp_icd.json ] || missing+=("mesa-vulkan-drivers")
    have unzip || missing+=("unzip")
    have curl || missing+=("curl")

    if [ ${#missing[@]} -eq 0 ]; then
        echo "apt packages already present"
        return 0
    fi
    if [ -z "$SUDO" ] && [ "$(id -u)" -ne 0 ]; then
        echo "skipping apt (no privileges): ${missing[*]}" >&2
        return 0
    fi

    echo "installing: ${missing[*]}"
    $SUDO apt-get update -q >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -q "${missing[@]}" >/dev/null 2>&1 \
        || echo "warning: apt install did not fully succeed" >&2
}

# ---------------------------------------------------------------- godot engine
install_godot() {
    if [ -x "$GODOT_BIN" ]; then
        echo "Godot already cached: $("$GODOT_BIN" --version 2>/dev/null)"
        return 0
    fi
    echo "downloading Godot ${GODOT_VERSION} to $CACHE_DIR"
    mkdir -p "$CACHE_DIR" || return 1
    curl -sSL -o "$CACHE_DIR/godot.zip" "$GODOT_URL" || {
        echo "warning: Godot download failed" >&2; return 1; }
    unzip -o -q "$CACHE_DIR/godot.zip" -d "$CACHE_DIR" || return 1
    rm -f "$CACHE_DIR/godot.zip"
    chmod +x "$GODOT_BIN"
    echo "installed: $("$GODOT_BIN" --version)"
}

# ------------------------------------------------------------ gdscript tooling
# gdtoolkit gives gdlint and gdformat. Newer Debian/Ubuntu images mark the system
# Python as externally managed, so fall back through --user and finally
# --break-system-packages rather than failing the whole setup.
install_gdtoolkit() {
    if have gdlint; then
        echo "gdtoolkit already present: $(gdlint --version 2>&1 | head -1)"
        return 0
    fi
    echo "installing gdtoolkit"
    pip install -q --disable-pip-version-check gdtoolkit 2>/dev/null \
        || pip install -q --disable-pip-version-check --user gdtoolkit 2>/dev/null \
        || pip install -q --disable-pip-version-check --break-system-packages gdtoolkit 2>/dev/null \
        || { echo "warning: gdtoolkit install failed" >&2; return 1; }
    have gdlint && echo "installed: $(gdlint --version 2>&1 | head -1)"
}

# ----------------------------------------------------------------------- report
report() {
    step "environment"
    printf '  %-22s %s\n' "Godot" \
        "$([ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null || echo 'MISSING')"
    printf '  %-22s %s\n' "python3" "$(python3 --version 2>&1 || echo MISSING)"
    printf '  %-22s %s\n' "gdlint" "$(have gdlint && gdlint --version 2>&1 | head -1 || echo MISSING)"
    printf '  %-22s %s\n' "gdformat" "$(have gdformat && echo present || echo MISSING)"
    printf '  %-22s %s\n' "xvfb-run" "$(have xvfb-run && echo present || echo 'MISSING (no rendering)')"
    printf '  %-22s %s\n' "software Vulkan" \
        "$([ -f /usr/share/vulkan/icd.d/lvp_icd.json ] && echo 'lavapipe (Forward+ testable)' || echo 'MISSING (Forward+ falls back to OpenGL)')"
    printf '  %-22s %s\n' "GPU device" "$([ -d /dev/dri ] && echo present || echo 'none (software rasterizer only)')"

    step "what you can do now"
    cat <<'USAGE'
  tools/godot_smoke_test.sh <project> [scene]                  import + headless boot
  tools/godot_smoke_test.sh <project> [scene] --render         + render a frame (OpenGL)
  tools/godot_smoke_test.sh <project> [scene] --forward-plus   + render a frame (Vulkan)
  gdlint <file.gd>            style check      gdformat <file.gd>   auto-format
  python3 tools/build_api_index.py             regenerate API lookup tables
  python3 tools/build_code_index.py            regenerate vendored-code symbol tables

  Read docs/CODESPACES.md before relying on any of it — notably, this machine cannot
  tell you anything about performance.
USAGE
}

if [ "$VERIFY_ONLY" = 0 ]; then
    step "apt packages";  install_apt
    step "godot engine";  install_godot
    step "gdscript tooling"; install_gdtoolkit
fi
report
