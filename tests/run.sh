#!/bin/sh
# Headless smoke tests. Needs the Luau CLI on PATH (or LUAU=/path/to/luau): https://github.com/luau-lang/luau/releases
set -e
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"

# The Luau CLI has no file reading, so the sources are packed into a module the tests can require.
pack() { printf '%s = [=====[\n' "$1"; cat "$2"; printf ']=====],\n'; }
{
	printf 'return {\n'
	pack TingUI TingUI.lua
	pack Example Example.lua
	pack LumenShim Lumen.lua
	pack Mock tests/mock_roblox.lua
	pack DataStoreStorage extras/DataStoreStorage.lua
	pack ConfigServer extras/ConfigServer.server.lua
	pack StudioDemo extras/StudioDemo.client.lua
	pack ExtendingDoc docs/extending.md
	pack LayoutsDoc docs/layouts.md
	printf '}\n'
} > tests/.sources.lua

trap "rm -f tests/.sources.lua" EXIT
"$LUAU" tests/run.lua
