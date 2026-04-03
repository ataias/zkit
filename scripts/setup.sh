#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SRC="$PROJECT_DIR/scripts/hooks"
HOOKS_DST="$PROJECT_DIR/.git/hooks"

for hook in "$HOOKS_SRC"/*; do
    name=$(basename "$hook")
    ln -sf "$hook" "$HOOKS_DST/$name"
    echo "Installed hook: $name"
done
