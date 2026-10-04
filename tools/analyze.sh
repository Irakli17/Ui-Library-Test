#!/usr/bin/env bash
# Static analysis for Vantage: Luau's type checker + linter, run against
# the official Roblox API definitions and a generated Rojo sourcemap.
#
#   ./tools/analyze.sh                     # analyse everything in src/
#   ./tools/analyze.sh src/Core/Theme.luau # analyse one file
#
# Exit code is non-zero when anything is reported.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

LSP="$ROOT/.tools/luau-lsp/luau-lsp.exe"
[ -x "$LSP" ] || LSP="$ROOT/.tools/luau-lsp/luau-lsp"
[ -x "$LSP" ] || LSP="$(command -v luau-lsp 2>/dev/null || true)"
if [ ! -x "$LSP" ]; then
  echo "luau-lsp not found. Run tools/install-toolchain.sh first." >&2
  exit 2
fi

DEFS="$ROOT/.tools/types/globalTypes.d.luau"
if [ ! -f "$DEFS" ]; then
  echo "globalTypes.d.luau not found. Run tools/install-toolchain.sh first." >&2
  exit 2
fi

if [ ! -f "$ROOT/sourcemap.json" ]; then
  node "$ROOT/tools/sourcemap.mjs" >/dev/null || exit 2
fi

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  mapfile -t TARGETS < <(find src -name '*.luau' | sort)
fi

"$LSP" analyze \
  --platform=roblox \
  --definitions="$DEFS" \
  --sourcemap="$ROOT/sourcemap.json" \
  --settings="$ROOT/.vantage/luau-lsp.json" \
  --ignore='**/.tools/**' \
  "${TARGETS[@]}"
