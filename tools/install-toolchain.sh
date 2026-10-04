#!/usr/bin/env bash
# Vantage · tools/install-toolchain.sh
# ------------------------------------------------------------------
# Fetches the tools the verification pipeline needs into `.tools/`.
#
# The Luau CLI is the only hard requirement: it runs the headless test
# suite and the loadstring integration suite, which execute the real
# library against a mock Roblox runtime. `luau-lsp` is optional and only
# used by tools/analyze.sh.
#
# Usage:
#   bash tools/install-toolchain.sh            # luau (+ analyzer types)
#   bash tools/install-toolchain.sh --with-lsp # also fetch luau-lsp
#
# Nothing here is committed: `.tools/` is git-ignored on purpose, because
# a repository should contain source, not binaries.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
mkdir -p "$TOOLS"

WITH_LSP=false
for arg in "$@"; do
	case "$arg" in
		--with-lsp) WITH_LSP=true ;;
	esac
done

# Luau ships per-platform archives: luau-windows.zip, luau-ubuntu.zip,
# luau-macos.zip. `luau-analyze` and `luau-compile` ride along.
os="$(uname -s)"
case "$os" in
	MINGW*|MSYS*|CYGWIN*|Windows_NT) asset="luau-windows.zip" ;;
	Darwin) asset="luau-macos.zip" ;;
	*) asset="luau-ubuntu.zip" ;;
esac

api="https://api.github.com/repos/luau-lang/luau/releases/latest"
echo "toolchain: resolving the latest Luau release…"
url="$(curl -fsSL "$api" | grep -o "https://[^\"]*$asset" | head -1)"

if [ -z "${url:-}" ]; then
	echo "toolchain: could not resolve $asset from the GitHub API." >&2
	echo "toolchain: download a Luau release manually and unzip it into .tools/luau/" >&2
	exit 1
fi

echo "toolchain: downloading $asset"
tmp="$(mktemp -d)"
curl -fsSL "$url" -o "$tmp/luau.zip"
mkdir -p "$TOOLS/luau"
if command -v unzip >/dev/null 2>&1; then
	unzip -o -q "$tmp/luau.zip" -d "$TOOLS/luau"
else
	# Git Bash on Windows does not always ship unzip.
	powershell -NoProfile -Command "Expand-Archive -Force '$tmp/luau.zip' '$TOOLS/luau'" >/dev/null
fi
rm -rf "$tmp"
chmod +x "$TOOLS/luau/"* 2>/dev/null || true

# Roblox API definitions for the analyzer. They are large, generated, and
# versioned upstream, so they are fetched rather than vendored.
types="$TOOLS/types"
mkdir -p "$types"
if [ ! -f "$types/globalTypes.d.luau" ]; then
	echo "toolchain: downloading the Roblox API definitions"
	curl -fsSL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" \
		-o "$types/globalTypes.d.luau"
fi

if [ "$WITH_LSP" = true ]; then
	echo "toolchain: resolving luau-lsp…"
	lsp_os="$os"
	case "$os" in
		MINGW*|MSYS*|CYGWIN*|Windows_NT) lsp_asset="luau-lsp-win64.zip" ;;
		Darwin) lsp_asset="luau-lsp-macos.zip" ;;
		*) lsp_asset="luau-lsp-linux.zip" ;;
	esac
	lsp_url="$(curl -fsSL "https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases/latest" \
		| grep -o "https://[^\"]*$lsp_asset" | head -1)"
	if [ -n "${lsp_url:-}" ]; then
		tmp="$(mktemp -d)"
		curl -fsSL "$lsp_url" -o "$tmp/lsp.zip"
		mkdir -p "$TOOLS/luau-lsp"
		if command -v unzip >/dev/null 2>&1; then
			unzip -o -q "$tmp/lsp.zip" -d "$TOOLS/luau-lsp"
		else
			powershell -NoProfile -Command "Expand-Archive -Force '$tmp/lsp.zip' '$TOOLS/luau-lsp'" >/dev/null
		fi
		rm -rf "$tmp"
		chmod +x "$TOOLS/luau-lsp/"* 2>/dev/null || true
	fi
fi

echo "toolchain: ready — run 'node tools/test.mjs' and 'node tools/verify-dist.mjs'."
