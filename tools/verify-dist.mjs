#!/usr/bin/env node
/**
 * Vantage · tools/verify-dist.mjs
 * ------------------------------------------------------------------
 * Proves the *shipped* file works the way users actually load it.
 *
 * `node tools/test.mjs` runs the source tree through a bundler and a
 * headless mock. That is a strong signal, but it does not answer the
 * question that matters most for a loadstring distribution:
 *
 *     If I point loadstring at this GitHub file, does it run?
 *
 * So this script does exactly that, and nothing softer:
 *
 *   1. Boots the mock Roblox runtime.
 *   2. Deletes the `script` global — an executor has no such global, and
 *      a bundle that touches it would break there while passing every
 *      Rojo-based test.
 *   3. Reads dist/Vantage.luau (and dist/Vantage.min.luau) from disk.
 *   4. Hands the bytes to `loadstring`, the way a loader script does.
 *   5. Runs tests/Integration.luau against the returned namespace.
 *
 * The bundle is embedded as a long string with a delimiter level computed
 * from its own contents, so no amount of brackets in the source can break
 * out of it.
 *
 * Usage:
 *   node tools/verify-dist.mjs            # both artifacts
 *   node tools/verify-dist.mjs --min      # the minified build only
 *   node tools/verify-dist.mjs --full     # the annotated build only
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const BUILD = join(ROOT, "tests", "build");

const LUAU_CANDIDATES = [join(ROOT, ".tools", "luau", "luau.exe"), join(ROOT, ".tools", "luau", "luau")];
const LUAU = LUAU_CANDIDATES.find((path) => existsSync(path)) ?? "luau";

const flags = process.argv.slice(2);
const MIN_ONLY = flags.includes("--min");
const FULL_ONLY = flags.includes("--full");

const artifacts = [
	{ label: "dist/Vantage.luau", file: "Vantage.luau", enabled: !MIN_ONLY },
	{ label: "dist/Vantage.min.luau", file: "Vantage.min.luau", enabled: !FULL_ONLY },
].filter((entry) => entry.enabled);

if (artifacts.length === 0) {
	console.error("verify-dist: pick one of --min or --full, not both.");
	process.exit(1);
}

function read(...parts) {
	return readFileSync(join(ROOT, ...parts), "utf8");
}

/**
 * Long-string level that the given source cannot terminate early. Luau
 * long strings are `[[ … ]]` with any number of `=` between the brackets.
 */
function safeLevel(source) {
	let level = 1;
	for (;;) {
		const closer = "]" + "=".repeat(level) + "]";
		if (!source.includes(closer)) return level;
		level += 1;
	}
}

const prelude = read("tests", "Mock", "prelude.luau");
const harness = read("tests", "Harness.luau");
const spec = read("tests", "Integration.luau");

mkdirSync(BUILD, { recursive: true });

let failures = 0;

for (const artifact of artifacts) {
	const source = read("dist", artifact.file);
	const level = safeLevel(source);
	const opener = "[" + "=".repeat(level) + "[";
	const closer = "]" + "=".repeat(level) + "]";

	const parts = [
		`-- GENERATED FILE — do not edit. Built by tools/verify-dist.mjs for ${artifact.label}.`,
		"",
		"-- ── mock Roblox runtime ─────────────────────────────────────────────",
		prelude,
		"",
		"-- ── an executor has no `script` global ──────────────────────────────",
		"-- The prelude defines one so the module tree can be resolved during",
		"-- unit tests; here it is deleted on purpose. Anything the bundle does",
		"-- with `script` would now fail loudly, exactly as it would in-game.",
		"script = nil",
		"assert(script == nil, \"verify-dist: the script global must be nil\")",
		"",
		"-- ── harness ─────────────────────────────────────────────────────────",
		"local Harness = (function()",
		harness,
		"end)()",
		"",
		"-- ── the shipped bytes, handed to loadstring ─────────────────────────",
		`local SOURCE = ${opener}`,
		source,
		`${closer}`,
		`local chunk, compileError = loadstring(SOURCE, "@${artifact.label}")`,
		"if not chunk then",
		`\terror("loadstring could not compile ${artifact.label}: " .. tostring(compileError))`,
		"end",
		"",
		"local Vantage = chunk()",
		"if type(Vantage) ~= \"table\" then",
		"\terror(\"loadstring returned \" .. type(Vantage) .. \", expected the Vantage namespace\")",
		"end",
		"",
		"-- Hand the animation scheduler to the mock so Mock.advance drives the",
		"-- same virtual clock the library animates on.",
		"Mock.motion = Vantage.Motion",
		"",
		"-- ── integration spec ────────────────────────────────────────────────",
		spec.trimEnd(),
		"",
		"-- ── report ──────────────────────────────────────────────────────────",
		`print(string.format("\\n\\27[1mVantage %s · loadstring integration%s\\27[0m\\n\\n", Vantage.version, " · ${artifact.label}"))`,
		'local failed = Harness.report("dist")',
		// The Luau CLI has no `os.exit`, and an exit code is a weak signal
		// anyway: the run prints a machine-readable result line that this
		// script requires before it will call the artifact verified.
		'print(string.format("RESULT fail=%d", failed))',
		"if failed > 0 then",
		'\terror(string.format("%d integration assertion(s) failed", failed), 0)',
		"end",
		"return 0",
		"",
	];

	const out = join(BUILD, `integration-${artifact.file.replace(/\.luau$/, "")}.luau`);
	writeFileSync(out, parts.join("\n"));

	const result = spawnSync(LUAU, ["-O2", out], { cwd: ROOT, encoding: "utf8" });

	if (result.error) {
		console.error(`verify-dist: could not launch ${LUAU}: ${result.error.message}`);
		console.error("verify-dist: run tools/install-toolchain.sh to fetch the Luau CLI.");
		process.exit(2);
	}

	process.stdout.write(result.stdout ?? "");
	process.stderr.write(result.stderr ?? "");

	const marker = (result.stdout ?? "").match(/RESULT fail=(\d+)/);
	if (!marker) {
		console.error(`verify-dist: ${artifact.label} never reached its result line.`);
		failures += 1;
	} else if (marker[1] !== "0") {
		failures += 1;
	}
}

if (failures > 0) {
	console.error(`verify-dist: ${failures} artifact(s) failed.`);
	process.exit(1);
}

console.log(`verify-dist: ${artifacts.length} artifact(s) run from loadstring without a script global.`);
