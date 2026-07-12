#!/usr/bin/env bash
#
# Re-apply the Nexus Music keyboard fix to the flutter_ohos engine HAR.
#
# The HarmonyOS text-input fix lives in @ohos/flutter_ohos's
# TextInputPlugin.ets. The project pins that package to a local HAR via the
# "overrides" entry in ohos/oh-package.json5, so the permanent fix is to patch
# that HAR in place. `ohpm install` extracts the (patched) source from it, and
# the app build compiles it.
#
# Run this script after:
#   - reinstalling / upgrading the flutter_ohos SDK, or
#   - running `flutter precache` / re-downloading the engine,
# which would otherwise restore the original (broken) HAR.
#
# Usage:
#   tools/apply_patch.sh                 # patches the default SDK HAR
#   SDK_HAR=/path/to.har tools/apply_patch.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PATCHED_HAR="${PROJECT_ROOT}/ohos/third_party/flutter_embedding_debug_patched.har"
SDK_HAR="${SDK_HAR:-/home/lex/ohos-sdk/flutter_ohos/bin/cache/artifacts/engine/ohos-arm64/flutter_embedding_debug.har}"
REL_HAR="${SDK_HAR}.orig.bak"

if [ ! -f "$PATCHED_HAR" ]; then
  echo "ERROR: patched HAR not found: $PATCHED_HAR" >&2
  exit 1
fi
if [ ! -f "$SDK_HAR" ]; then
  echo "ERROR: SDK HAR not found: $SDK_HAR" >&2
  echo "Set SDK_HAR to the correct flutter_embedding_debug.har path." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Extract the current SDK HAR
gunzip -c "$SDK_HAR" | tar -xf - -C "$TMP"

# Extract the patched TextInputPlugin.ets from the committed patched HAR
mkdir -p "$TMP/patched_src"
gunzip -c "$PATCHED_HAR" | tar -xf - -C "$TMP/patched_src"

SRC="$TMP/patched_src/package/src/main/ets/plugin/editing/TextInputPlugin.ets"
DST="$TMP/package/src/main/ets/plugin/editing/TextInputPlugin.ets"

if [ ! -f "$SRC" ]; then
  echo "ERROR: TextInputPlugin.ets missing inside patched HAR" >&2
  exit 1
fi

if diff -q "$SRC" "$DST" >/dev/null 2>&1; then
  echo "Already patched: $SDK_HAR (no change needed)"
  exit 0
fi

# Back up the original once
if [ ! -f "$REL_HAR" ]; then
  cp "$SDK_HAR" "$REL_HAR"
  echo "Backed up original to $REL_HAR"
fi

cp "$SRC" "$DST"

# Repackage, preserving the package/ top-level prefix
tar -czf "$SDK_HAR" -C "$TMP" package

echo "Patched HAR written to $SDK_HAR"
echo "Run 'cd ohos && ohpm install' (or 'flutter build hap') to pick it up."
