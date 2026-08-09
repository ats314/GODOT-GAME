#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Remote sessions get a fresh container each time, so without this an agent starts with
# no engine, no linter and no way to render — and tends to reason about the project
# instead of verifying it. This installs the same toolchain the Codespaces devcontainer
# installs, from the same script, so both environments can do the same things.
#
# Local sessions are left alone: developers manage their own machines.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

bash "$PROJECT_DIR/tools/setup_environment.sh"

# Make the engine path available to the rest of the session so nothing has to guess it.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    GODOT_BIN="$HOME/.cache/godot-bin/Godot_v4.7.1-stable_linux.x86_64"
    if [ -x "$GODOT_BIN" ]; then
        echo "export GODOT_BIN=\"$GODOT_BIN\"" >> "$CLAUDE_ENV_FILE"
    fi
fi
