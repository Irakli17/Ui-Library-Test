#!/usr/bin/env node
/**
 * Vantage · tools/test.mjs
 * ------------------------------------------------------------------
 * Builds and runs the headless test suite.
 *
 * The suite executes the *real* library — the same source that ships in
 * `dist/Vantage.luau` — against a mock Roblox runtime. Nothing is
 * stubbed out at the module level, so a passing run means the actual
 * code paths constructed instances, animated them and tore them down.
 *
 * The generated file is assembled in a specific order:
 *
 *   prelude   ─ mock globals (Instance, Color3, task, services)
 *   Vantage   ─ the real bundle, wrapped in an IIFE so its trailing
 *               `return` does not end the enclosing chunk
 *   harness   ─ describe/it/expect
 *   specs     ─ every file in tests/Specs, in sorted order
 *   runner    ─ reports and exits with the failure count
 *
 * Usage:
 *   node tools/test.mjs            # run everything
 *   node tools/test.mjs Core       # filter suites by name substring
 */

import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const BUILD = join(ROOT, "tests", "build");
const OUT = join(BUILD, "suite.luau");
const FILTER = process.argv[2] ?? "";

const LUAU_CANDIDATES = [
	join(ROOT, ".tools", "luau", "luau.exe"),
	join(ROOT, ".tools", "luau", "luau"),
];
const LUAU = LUAU_CANDIDATES.find((path) => existsSync(path)) ?? "luau";

function read(path) {
	return readFileSync(path, "utf8");
}

/* Ensure the bundle is current. */
if (!existsSync(join(ROOT, "dist", "Vantage.luau"))) {
	const bundle = spawnSync(process.execPath, [join(ROOT, "tools", "bundle.mjs")], {
		cwd: ROOT,
		stdio: "inherit",
	});
	if (bundle.status !== 0) process.exit(bundle.status ?? 1);
}

const specs = readdirSync(join(ROOT, "tests", "Specs"))
	.filter((name) => name.endsWith(".luau"))
	.sort()
	.filter((name) => (FILTER ? name.toLowerCase().includes(FILTER.toLowerCase()) : true));

if (specs.length === 0) {
	console.error(`test: no spec files matched "${FILTER}"`);
	process.exit(1);
}

const parts = [
	"-- GENERATED FILE — do not edit. Built by tools/test.mjs.",
	"",
	read(join(ROOT, "tests", "Mock", "prelude.luau")),
	"",
	"-- ── Vantage bundle ──────────────────────────────────────────────",
	"local Vantage = (function()",
	read(join(ROOT, "dist", "Vantage.luau")),
	"end)()",
	"",
	"-- Hand the animation scheduler to the mock so Mock.advance drives the",
	"-- same virtual clock the library animates on.",
	"Mock.motion = Vantage.Motion",
	"",
	"-- ── Harness ─────────────────────────────────────────────────────",
	"local Harness = (function()",
	read(join(ROOT, "tests", "Harness.luau")),
	"end)()",
	"",
];

for (const name of specs) {
	parts.push(`-- ── Spec: ${name} ${"─".repeat(Math.max(2, 52 - name.length))}`);
	parts.push(`do`);
	parts.push(read(join(ROOT, "tests", "Specs", name)).trimEnd());
	parts.push(`end`);
	parts.push("");
}

parts.push(`-- ── Report ─────────────────────────────────────────────────────`);
parts.push(`print(string.format("\\n\\27[1mVantage %s · headless suite\\27[0m  (%s)\\n\\n", Vantage.version, "${specs.join(", ")}"))`);
parts.push(`local failed = Harness.report("suite")`);
// The Luau CLI has no `os.exit`, and an exit code is a weak signal anyway:
// the run prints a machine-readable result line that this script requires
// before it will call the suite green.
parts.push(`print(string.format("RESULT fail=%d", failed))`);
parts.push(`if failed > 0 then`);
parts.push(`\terror(string.format("%d assertion(s) failed", failed), 0)`);
parts.push(`end`);
parts.push(`return 0`);
parts.push("");

mkdirSync(BUILD, { recursive: true });
writeFileSync(OUT, parts.join("\n"));

const result = spawnSync(LUAU, ["-O2", OUT], {
	cwd: ROOT,
	encoding: "utf8",
});

if (result.error) {
	console.error(`test: could not launch ${LUAU}: ${result.error.message}`);
	console.error("test: run tools/install-toolchain.sh to fetch the Luau CLI.");
	process.exit(2);
}

process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");

const marker = (result.stdout ?? "").match(/RESULT fail=(\d+)/);
if (!marker) {
	console.error("test: the suite never reached its result line.");
	process.exit(1);
}
process.exit(marker[1] === "0" ? 0 : 1);
